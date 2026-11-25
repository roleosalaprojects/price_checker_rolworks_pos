/* apex_fingerprint — the fingerprint reader for the Apex POS and the Price
 * Checker kiosk (DigitalPersona U.are.U 4500 through libfprint, Linux).
 *
 * The app starts this program and talks to it with one JSON object per line:
 * commands on stdin, events on stdout. Only protocol lines reach stdout;
 * everything else (libfprint's logging included) goes to stderr.
 *
 * Commands
 *   {"cmd":"status"}
 *   {"cmd":"gallery","params":{"match_min":40,"sign_in_min":55,"margin":10},
 *    "prints":[{"id":"12","user_id":"17","print":"<base64 FP3>"}]}
 *   {"cmd":"scan","req":"r1","purpose":"punch"|"sign_in","timeout":20}
 *        (+ "all_scores":true: the match / no_match also lists every person's
 *         best score, scores:[{user_id, score}] — for calibration only)
 *   {"cmd":"enroll","req":"r2","user_id":"17","finger":"right_index","timeout":120}
 *   {"cmd":"verify","req":"r3","user_id":"17","print":"<base64 FP3>","timeout":20}
 *   {"cmd":"cancel"}
 *   {"cmd":"quit"}
 *
 * Events
 *   reader {connected, name, driver, stages, temperature}
 *                                                on start, plug / unplug, cold / warm / hot
 *   gallery {loaded, skipped:[ids]}
 *   waiting {req}                                the reader waits for a finger
 *   paused {req, seconds}                        after 5 no-matches in a row
 *   retry {req, reason}                          too_short | center | remove | general
 *   stage {req, done, of}                        an enrolment press counted
 *   match {req, user_id, print_id, score, second}
 *   no_match {req, best, second}
 *   enrolled {req, print, weakest, duplicates:[{user_id, score}]}
 *   enroll_failed {req, reason:"mixed", weakest}
 *   verified {req, ok, score, duplicates:[...]}
 *   cancelled {req}
 *   timeout {req}                                no finger within "timeout" seconds
 *   error {req?, code: NO_READER|BUSY|BAD_CMD|BAD_PRINT|HOT|LIBFPRINT, message}
 *   idle {req}                                   the action is over; send the next
 *
 * Matching happens here, never on the server: the server only stores prints.
 *
 * The reader is armed on demand, never left waiting: libfprint (1.94) models
 * a sensor's temperature and, after about 4 minutes of continuous waiting
 * (3 min "hot" time constant, the default for the U.are.U 4500's driver),
 * refuses every action for about 3 minutes ("HOT"). So every action has a
 * timeout and the apps arm the reader when someone taps.
 * Source of truth: apex_pos/native/apex_fingerprint. The kiosk carries a copy.
 */
#include <errno.h>
#include <fprint.h>
#include <glib-unix.h>
#include <json-glib/json-glib.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#ifdef __linux__
#include <sys/prctl.h>
#endif
#include <unistd.h>

#include "prints.h"

#define APEX_FP_VERSION       "1.0.0"
#define PAUSE_AFTER_NO_MATCH  5
#define PAUSE_SECONDS         30
#define SCAN_TIMEOUT          20
#define ENROLL_TIMEOUT        120

typedef enum { OP_NONE, OP_SCAN, OP_ENROLL, OP_VERIFY } OpKind;

static struct
{
  GMainLoop    *loop;
  FILE         *proto;          /* the real stdout */
  FpContext    *ctx;
  FpDevice     *dev;            /* open reader, or NULL */
  FpDevice     *opening;        /* reader being opened */
  guint         reopen_source;
  guint         reopen_delay;

  OpKind        op;
  gchar        *req;
  gboolean      sign_in;        /* scan purpose */
  gboolean      all_scores;     /* scan: every person's score too (calibration) */
  gchar        *user_id;        /* enrol / verify: whose finger */
  FpFinger      finger;
  ApexPrint    *target;         /* verify: the print to check against */
  GCancellable *cancel;
  gboolean      cancel_requested;
  gboolean      result_sent;
  guint         pause_source;
  guint         timeout_source;
  gboolean      timed_out;

  GPtrArray    *gallery;        /* ApexPrint * */
  int           match_min;
  int           sign_in_min;
  int           margin;
  int           no_match_streak;
  gint64        paused_until;   /* monotonic µs */
} S;

/* ------------------------------------------------------------------ output */

static JsonBuilder *
ev (const gchar *event, const gchar *req)
{
  JsonBuilder *b = json_builder_new ();

  json_builder_begin_object (b);
  json_builder_set_member_name (b, "event");
  json_builder_add_string_value (b, event);
  if (req)
    {
      json_builder_set_member_name (b, "req");
      json_builder_add_string_value (b, req);
    }
  return b;
}

static void
put_str (JsonBuilder *b, const gchar *key, const gchar *value)
{
  json_builder_set_member_name (b, key);
  if (value)
    json_builder_add_string_value (b, value);
  else
    json_builder_add_null_value (b);
}

static void
put_int (JsonBuilder *b, const gchar *key, gint64 value)
{
  json_builder_set_member_name (b, key);
  json_builder_add_int_value (b, value);
}

static void
put_bool (JsonBuilder *b, const gchar *key, gboolean value)
{
  json_builder_set_member_name (b, key);
  json_builder_add_boolean_value (b, value);
}

static void
send_event (JsonBuilder *b)
{
  g_autoptr(JsonGenerator) gen = json_generator_new ();
  g_autoptr(JsonNode) root = NULL;
  g_autofree gchar *line = NULL;

  json_builder_end_object (b);
  root = json_builder_get_root (b);
  json_generator_set_root (gen, root);
  line = json_generator_to_data (gen, NULL);
  fputs (line, S.proto);
  fputc ('\n', S.proto);
  fflush (S.proto);
  g_object_unref (b);
}

static void
send_error (const gchar *req, const gchar *code, const gchar *message)
{
  JsonBuilder *b = ev ("error", req);

  put_str (b, "code", code);
  put_str (b, "message", message);
  send_event (b);
}

static const gchar *
temperature_name (FpTemperature t)
{
  switch (t)
    {
    case FP_TEMPERATURE_HOT:
      return "hot";
    case FP_TEMPERATURE_WARM:
      return "warm";
    default:
      return "cold";
    }
}

/* What an action's failure means to the app. */
static const gchar *
error_code (const GError *error)
{
  if (g_error_matches (error, FP_DEVICE_ERROR, FP_DEVICE_ERROR_TOO_HOT))
    return "HOT";
  if (g_error_matches (error, FP_DEVICE_ERROR, FP_DEVICE_ERROR_REMOVED) ||
      g_error_matches (error, FP_DEVICE_ERROR, FP_DEVICE_ERROR_NOT_OPEN))
    return "NO_READER";
  return "LIBFPRINT";
}

/* Reopen the reader after a failure that may have left it stuck (a powerup
 * timeout, a protocol error) — not after "too hot" or bad data. */
static gboolean
needs_reopen (const GError *error)
{
  return error->domain == FP_DEVICE_ERROR &&
         (error->code == FP_DEVICE_ERROR_GENERAL || error->code == FP_DEVICE_ERROR_PROTO);
}

static void
send_reader (void)
{
  JsonBuilder *b = ev ("reader", NULL);

  put_bool (b, "connected", S.dev != NULL);
  if (S.dev)
    {
      put_str (b, "name", fp_device_get_name (S.dev));
      put_str (b, "driver", fp_device_get_driver (S.dev));
      put_int (b, "stages", fp_device_get_nr_enroll_stages (S.dev));
      put_str (b, "temperature", temperature_name (fp_device_get_temperature (S.dev)));
    }
  put_int (b, "gallery", S.gallery->len);
  put_str (b, "version", APEX_FP_VERSION);
  send_event (b);
}

/* Everything libfprint and GLib log goes to stderr, never into the protocol. */
static GLogWriterOutput
log_to_stderr (GLogLevelFlags   level,
               const GLogField *fields,
               gsize            n_fields,
               gpointer         user_data)
{
  const gchar *domain = NULL;
  g_autofree gchar *text = NULL;
  gsize i;

  for (i = 0; i < n_fields; i++)
    if (g_strcmp0 (fields[i].key, "GLIB_DOMAIN") == 0)
      domain = fields[i].value;
  if (g_log_writer_default_would_drop (level, domain))
    return G_LOG_WRITER_HANDLED;
  text = g_log_writer_format_fields (level, fields, n_fields, FALSE);
  fprintf (stderr, "%s\n", text);
  return G_LOG_WRITER_HANDLED;
}

/* ------------------------------------------------------------- the reader */

static void open_reader (FpDevice *device);

static gboolean
reopen_cb (gpointer data)
{
  FpDevice *device = data;

  S.reopen_source = 0;
  open_reader (device);
  return G_SOURCE_REMOVE;
}

static void
schedule_reopen (FpDevice *device)
{
  if (S.reopen_source)
    return;
  S.reopen_delay = S.reopen_delay ? MIN (S.reopen_delay * 2, 30) : 2;
  S.reopen_source = g_timeout_add_seconds_full (G_PRIORITY_DEFAULT, S.reopen_delay, reopen_cb,
                                                g_object_ref (device), g_object_unref);
}

static void
on_temperature (GObject *device, GParamSpec *pspec, gpointer data)
{
  if (FP_DEVICE (device) == S.dev)
    send_reader ();
}

static void
on_opened (GObject *source, GAsyncResult *res, gpointer data)
{
  FpDevice *device = FP_DEVICE (source);
  g_autoptr(GError) error = NULL;

  if (S.opening == device)
    S.opening = NULL;
  if (!fp_device_open_finish (device, res, &error))
    {
      send_error (NULL, "LIBFPRINT", error->message);
      schedule_reopen (device);
      return;
    }
  S.reopen_delay = 0;
  g_set_object (&S.dev, device);
  g_signal_connect (device, "notify::temperature", G_CALLBACK (on_temperature), NULL);
  send_reader ();
}

static gboolean
wanted (FpDevice *device)
{
  const gchar *only = g_getenv ("APEX_FP_DRIVER");

  if (only && *only)
    return g_strcmp0 (fp_device_get_driver (device), only) == 0;
  return fp_device_has_feature (device, FP_DEVICE_FEATURE_IDENTIFY);
}

static void
open_reader (FpDevice *device)
{
  if (S.dev || S.opening || !wanted (device))
    return;
  if (fp_device_is_open (device))
    {
      g_set_object (&S.dev, device);
      send_reader ();
      return;
    }
  S.opening = device;
  fp_device_open (device, NULL, on_opened, NULL);
}

static void
on_device_added (FpContext *ctx, FpDevice *device, gpointer data)
{
  open_reader (device);
}

static void
on_device_removed (FpContext *ctx, FpDevice *device, gpointer data)
{
  if (device != S.dev)
    return;
  if (S.cancel)
    g_cancellable_cancel (S.cancel);
  g_clear_object (&S.dev);
  send_reader ();
}

/* --------------------------------------------------------------- actions */

static void
op_reset (void)
{
  S.op = OP_NONE;
  g_clear_pointer (&S.req, g_free);
  g_clear_pointer (&S.user_id, g_free);
  g_clear_pointer (&S.target, apex_print_free);
  g_clear_object (&S.cancel);
  if (S.timeout_source)
    g_source_remove (S.timeout_source);
  S.timeout_source = 0;
  S.cancel_requested = FALSE;
  S.timed_out = FALSE;
  S.result_sent = FALSE;
}

/* The action is over: tell the app, which may now send the next one. */
static void
op_finish (gboolean cancelled)
{
  g_autofree gchar *req = g_strdup (S.req);

  if (S.timed_out)
    send_event (ev ("timeout", req));
  else if (cancelled)
    send_event (ev ("cancelled", req));
  op_reset ();
  send_event (ev ("idle", req));
}

static const gchar *
retry_reason (const GError *error)
{
  switch (error->code)
    {
    case FP_DEVICE_RETRY_TOO_SHORT:
      return "too_short";
    case FP_DEVICE_RETRY_CENTER_FINGER:
      return "center";
    case FP_DEVICE_RETRY_REMOVE_FINGER:
      return "remove";
    default:
      return "general";
    }
}

static void
send_retry (const GError *error)
{
  JsonBuilder *b = ev ("retry", S.req);

  put_str (b, "reason", retry_reason (error));
  send_event (b);
}

/* The scanned finger as a probe (the first and only minutiae set). */
static GPtrArray *
probe_of (FpPrint *print, GError **error)
{
  g_autofree guchar *data = NULL;
  gsize length = 0;
  GPtrArray *subs = NULL;

  if (!fp_print_serialize (print, &data, &length, error))
    return NULL;
  if (!apex_print_parse (data, length, NULL, &subs, error))
    return NULL;
  return subs;
}

typedef struct
{
  const gchar *user_id;
  const gchar *print_id;
  int          score;
} Best;

/* A score past which a print plainly matches; scoring stops there. Two people
 * both past it would be ambiguous anyway (refused by the margin). */
static int
enough (void)
{
  return MAX (200, MAX (S.sign_in_min, S.match_min) + S.margin);
}

/* Best score per person, over every print and press of the gallery.
 * @skip_user: leave this person out (an enrolment's own finger). */
static GHashTable *
score_gallery (struct xyt_struct *probe, const gchar *skip_user)
{
  GHashTable *people = g_hash_table_new_full (g_str_hash, g_str_equal, NULL, g_free);
  const gchar *driver = S.dev ? fp_device_get_driver (S.dev) : NULL;
  int len = apex_probe_init (probe);
  guint i;

  for (i = 0; i < S.gallery->len; i++)
    {
      ApexPrint *p = g_ptr_array_index (S.gallery, i);
      Best *best;
      int score;

      if (skip_user && g_strcmp0 (p->user_id, skip_user) == 0)
        continue;
      if (driver && g_strcmp0 (p->driver, driver) != 0)
        continue;
      score = apex_best_score (len, probe, p->subs, enough ());
      best = g_hash_table_lookup (people, p->user_id);
      if (best == NULL)
        {
          best = g_new0 (Best, 1);
          best->user_id = p->user_id;
          g_hash_table_insert (people, p->user_id, best);
        }
      if (score > best->score || best->print_id == NULL)
        {
          best->score = score;
          best->print_id = p->id;
        }
    }
  return people;
}

static void
top_two (GHashTable *people, Best *first, int *second)
{
  GHashTableIter it;
  gpointer value;

  memset (first, 0, sizeof (*first));
  *second = 0;
  g_hash_table_iter_init (&it, people);
  while (g_hash_table_iter_next (&it, NULL, &value))
    {
      Best *b = value;

      if (b->score > first->score)
        {
          *second = first->score;
          *first = *b;
        }
      else if (b->score > *second)
        {
          *second = b->score;
        }
    }
}

static void
put_duplicates (JsonBuilder *b, GHashTable *people)
{
  GHashTableIter it;
  gpointer value;

  json_builder_set_member_name (b, "duplicates");
  json_builder_begin_array (b);
  g_hash_table_iter_init (&it, people);
  while (g_hash_table_iter_next (&it, NULL, &value))
    {
      Best *best = value;

      if (best->score < S.match_min)
        continue;
      json_builder_begin_object (b);
      put_str (b, "user_id", best->user_id);
      put_int (b, "score", best->score);
      json_builder_end_object (b);
    }
  json_builder_end_array (b);
}

/* Every person's best score — asked for by the enrol station's calibration
 * ("all_scores": true on a scan); the apps never ask. */
static void
put_scores (JsonBuilder *b, GHashTable *people)
{
  GHashTableIter it;
  gpointer value;

  json_builder_set_member_name (b, "scores");
  json_builder_begin_array (b);
  g_hash_table_iter_init (&it, people);
  while (g_hash_table_iter_next (&it, NULL, &value))
    {
      Best *best = value;

      json_builder_begin_object (b);
      put_str (b, "user_id", best->user_id);
      put_int (b, "score", best->score);
      json_builder_end_object (b);
    }
  json_builder_end_array (b);
}

static void
scan_result (FpPrint *print)
{
  g_autoptr(GError) error = NULL;
  g_autoptr(GPtrArray) probe = probe_of (print, &error);
  g_autoptr(GHashTable) people = NULL;
  struct xyt_struct *p;

  S.result_sent = TRUE;
  if (probe == NULL)
    {
      send_error (S.req, "LIBFPRINT", error ? error->message : "no minutiae");
      return;
    }
  p = g_ptr_array_index (probe, 0);
  g_debug ("scan: %d minutiae", p->nrows);

  if (S.op == OP_VERIFY)
    {
      JsonBuilder *b = ev ("verified", S.req);
      int score = apex_best_score (apex_probe_init (p), p, S.target->subs, enough ());

      people = score_gallery (p, S.user_id);
      put_bool (b, "ok", score >= S.match_min);
      put_int (b, "score", score);
      put_duplicates (b, people);
      send_event (b);
      return;
    }

  {
    Best first;
    int second, needed = S.sign_in ? S.sign_in_min : S.match_min;
    JsonBuilder *b;

    gint64 started = g_get_monotonic_time ();

    people = score_gallery (p, NULL);
    top_two (people, &first, &second);
    g_debug ("scored %u prints in %" G_GINT64_FORMAT " ms", S.gallery->len,
             (g_get_monotonic_time () - started) / 1000);
    if (first.user_id && first.score >= needed && first.score - second >= S.margin)
      {
        S.no_match_streak = 0;
        b = ev ("match", S.req);
        put_str (b, "user_id", first.user_id);
        put_str (b, "print_id", first.print_id);
        put_int (b, "score", first.score);
        put_int (b, "second", second);
      }
    else
      {
        if (++S.no_match_streak >= PAUSE_AFTER_NO_MATCH)
          {
            S.no_match_streak = 0;
            S.paused_until = g_get_monotonic_time () + (gint64) PAUSE_SECONDS * G_USEC_PER_SEC;
          }
        b = ev ("no_match", S.req);
        put_int (b, "best", first.score);
        put_int (b, "second", second);
      }
    if (S.all_scores)
      put_scores (b, people);
    send_event (b);
  }
}

static void start_identify (void);

static gboolean
on_timeout (gpointer data)
{
  S.timeout_source = 0;
  S.timed_out = TRUE;
  if (S.pause_source)
    {
      g_source_remove (S.pause_source);
      S.pause_source = 0;
      op_finish (TRUE);
    }
  else if (S.cancel)
    g_cancellable_cancel (S.cancel);
  return G_SOURCE_REMOVE;
}

static void
arm_timeout (JsonObject *o, int fallback)
{
  int seconds = fallback;
  JsonNode *n = json_object_get_member (o, "timeout");

  if (n && JSON_NODE_TYPE (n) == JSON_NODE_VALUE && json_node_get_value_type (n) == G_TYPE_INT64)
    seconds = (int) json_node_get_int (n);
  if (seconds > 0)
    S.timeout_source = g_timeout_add_seconds ((guint) seconds, on_timeout, NULL);
}

static void
on_identify_match (FpDevice *device,
                   FpPrint  *match,
                   FpPrint  *print,
                   gpointer  data,
                   GError   *error)
{
  if (error)
    {
      if (error->domain == FP_DEVICE_RETRY)
        send_retry (error);
      return;
    }
  if (print && !S.result_sent)
    scan_result (print);
}

static void
on_identify_done (GObject *source, GAsyncResult *res, gpointer data)
{
  FpDevice *device = FP_DEVICE (source);
  g_autoptr(GError) error = NULL;
  g_autoptr(FpPrint) match = NULL;
  g_autoptr(FpPrint) print = NULL;

  if (!fp_device_identify_finish (device, res, &match, &print, &error))
    {
      if (S.cancel_requested || g_error_matches (error, G_IO_ERROR, G_IO_ERROR_CANCELLED))
        {
          op_finish (TRUE);
          return;
        }
      if (error->domain == FP_DEVICE_RETRY)
        {
          /* A bad press: the app was told; keep waiting for a good one. */
          S.result_sent = FALSE;
          start_identify ();
          return;
        }
      send_error (S.req, error_code (error), error->message);
      op_finish (FALSE);
      if (S.dev == device && needs_reopen (error))
        {
          g_clear_object (&S.dev);
          send_reader ();
          fp_device_close (device, NULL, NULL, NULL);
          schedule_reopen (device);
        }
      return;
    }
  if (!S.result_sent && print)
    scan_result (print);
  op_finish (FALSE);
}

static gboolean
resume_after_pause (gpointer data)
{
  S.pause_source = 0;
  start_identify ();
  return G_SOURCE_REMOVE;
}

/* Scan a finger: identify against an empty gallery gives the scanned print
 * (libfprint 1.94 accepts an empty array), which we score ourselves. */
static void
start_identify (void)
{
  g_autoptr(GPtrArray) none = g_ptr_array_new_with_free_func (g_object_unref);
  gint64 now = g_get_monotonic_time ();

  if (S.dev == NULL)
    {
      send_error (S.req, "NO_READER", "No fingerprint reader is connected.");
      op_finish (FALSE);
      return;
    }
  if (S.op == OP_SCAN && S.paused_until > now)
    {
      JsonBuilder *b = ev ("paused", S.req);
      guint seconds = (guint) ((S.paused_until - now + G_USEC_PER_SEC - 1) / G_USEC_PER_SEC);

      put_int (b, "seconds", seconds);
      send_event (b);
      S.pause_source = g_timeout_add_seconds (seconds, resume_after_pause, NULL);
      return;
    }
  g_clear_object (&S.cancel);
  S.cancel = g_cancellable_new ();
  fp_device_identify (S.dev, none, S.cancel, on_identify_match, NULL, NULL,
                      on_identify_done, NULL);
  send_event (ev ("waiting", S.req));
}

static void
on_enroll_progress (FpDevice *device,
                    gint      completed,
                    FpPrint  *print,
                    gpointer  data,
                    GError   *error)
{
  JsonBuilder *b;

  if (error)
    {
      if (error->domain == FP_DEVICE_RETRY)
        send_retry (error);
      return;
    }
  b = ev ("stage", S.req);
  put_int (b, "done", completed);
  put_int (b, "of", fp_device_get_nr_enroll_stages (device));
  send_event (b);
}

static void
on_enroll_done (GObject *source, GAsyncResult *res, gpointer data)
{
  FpDevice *device = FP_DEVICE (source);
  g_autoptr(GError) error = NULL;
  g_autoptr(FpPrint) print = fp_device_enroll_finish (device, res, &error);
  g_autofree guchar *bytes = NULL;
  g_autofree gchar *b64 = NULL;
  g_autoptr(GPtrArray) subs = NULL;
  g_autoptr(GHashTable) people = NULL;
  gsize length = 0;
  int weakest = 0;
  gboolean consistent;
  gint64 started;
  guint i;
  JsonBuilder *b;

  if (print == NULL)
    {
      if (S.cancel_requested || g_error_matches (error, G_IO_ERROR, G_IO_ERROR_CANCELLED))
        op_finish (TRUE);
      else
        {
          send_error (S.req, error ? error_code (error) : "LIBFPRINT",
                      error ? error->message : "enrolment failed");
          op_finish (FALSE);
        }
      return;
    }

  if (!fp_print_serialize (print, &bytes, &length, &error) ||
      !apex_print_parse (bytes, length, NULL, &subs, &error))
    {
      send_error (S.req, "LIBFPRINT", error->message);
      op_finish (FALSE);
      return;
    }

  /* All presses must be one finger; the same finger must not already be
   * someone else's (one person enrolled under two names). */
  started = g_get_monotonic_time ();
  consistent = apex_subs_consistent (subs, S.match_min, &weakest);
  g_debug ("enrol: %u presses checked in %" G_GINT64_FORMAT " ms (weakest %d)", subs->len,
           (g_get_monotonic_time () - started) / 1000, weakest);
  if (!consistent)
    {
      b = ev ("enroll_failed", S.req);
      put_str (b, "reason", "mixed");
      put_int (b, "weakest", weakest);
      send_event (b);
      op_finish (FALSE);
      return;
    }

  started = g_get_monotonic_time ();
  people = g_hash_table_new_full (g_str_hash, g_str_equal, NULL, g_free);
  for (i = 0; i < subs->len; i++)
    {
      g_autoptr(GHashTable) one = score_gallery (g_ptr_array_index (subs, i), S.user_id);
      GHashTableIter it;
      gpointer value;

      g_hash_table_iter_init (&it, one);
      while (g_hash_table_iter_next (&it, NULL, &value))
        {
          Best *found = value, *kept = g_hash_table_lookup (people, found->user_id);

          if (kept == NULL)
            {
              kept = g_new0 (Best, 1);
              kept->user_id = found->user_id;
              g_hash_table_insert (people, (gpointer) found->user_id, kept);
            }
          kept->score = MAX (kept->score, found->score);
        }
    }

  g_debug ("enrol: duplicates checked in %" G_GINT64_FORMAT " ms",
           (g_get_monotonic_time () - started) / 1000);
  b64 = g_base64_encode (bytes, length);
  b = ev ("enrolled", S.req);
  put_str (b, "print", b64);
  put_int (b, "weakest", weakest);
  put_duplicates (b, people);
  send_event (b);
  op_finish (FALSE);
}

static void
start_enroll (void)
{
  FpPrint *template;

  if (S.dev == NULL)
    {
      send_error (S.req, "NO_READER", "No fingerprint reader is connected.");
      op_finish (FALSE);
      return;
    }
  template = fp_print_new (S.dev);
  fp_print_set_finger (template, S.finger);
  fp_print_set_username (template, S.user_id);
  S.cancel = g_cancellable_new ();
  fp_device_enroll (S.dev, template, S.cancel, on_enroll_progress, NULL, NULL,
                    on_enroll_done, NULL);
  send_event (ev ("waiting", S.req));
}

/* -------------------------------------------------------------- commands */

static const gchar *
member_str (JsonObject *o, const gchar *key)
{
  JsonNode *n = json_object_get_member (o, key);

  if (n == NULL || JSON_NODE_TYPE (n) != JSON_NODE_VALUE)
    return NULL;
  if (json_node_get_value_type (n) == G_TYPE_STRING)
    return json_node_get_string (n);
  return NULL;
}

/* Ids may come as numbers or strings; keep them as text. */
static gchar *
member_id (JsonObject *o, const gchar *key)
{
  JsonNode *n = json_object_get_member (o, key);

  if (n == NULL || JSON_NODE_TYPE (n) != JSON_NODE_VALUE)
    return NULL;
  if (json_node_get_value_type (n) == G_TYPE_STRING)
    return g_strdup (json_node_get_string (n));
  if (json_node_get_value_type (n) == G_TYPE_INT64)
    return g_strdup_printf ("%" G_GINT64_FORMAT, json_node_get_int (n));
  return NULL;
}

static gboolean
member_bool (JsonObject *o, const gchar *key)
{
  JsonNode *n = o ? json_object_get_member (o, key) : NULL;

  return n != NULL && JSON_NODE_TYPE (n) == JSON_NODE_VALUE
         && json_node_get_value_type (n) == G_TYPE_BOOLEAN && json_node_get_boolean (n);
}

static int
member_int (JsonObject *o, const gchar *key, int fallback)
{
  JsonNode *n = o ? json_object_get_member (o, key) : NULL;

  if (n == NULL || JSON_NODE_TYPE (n) != JSON_NODE_VALUE)
    return fallback;
  if (json_node_get_value_type (n) == G_TYPE_INT64)
    return (int) json_node_get_int (n);
  if (json_node_get_value_type (n) == G_TYPE_DOUBLE)
    return (int) json_node_get_double (n);
  return fallback;
}

static FpFinger
finger_of (const gchar *name)
{
  static const gchar *names[] = {
    "left_thumb", "left_index", "left_middle", "left_ring", "left_little",
    "right_thumb", "right_index", "right_middle", "right_ring", "right_little",
  };
  guint i;

  for (i = 0; i < G_N_ELEMENTS (names); i++)
    if (g_strcmp0 (name, names[i]) == 0)
      return (FpFinger) (FP_FINGER_LEFT_THUMB + i);
  return FP_FINGER_UNKNOWN;
}

static void
cmd_gallery (JsonObject *o)
{
  JsonObject *params = json_object_has_member (o, "params") ?
                       json_object_get_object_member (o, "params") : NULL;
  JsonArray *prints = json_object_has_member (o, "prints") ?
                      json_object_get_array_member (o, "prints") : NULL;
  GPtrArray *gallery = g_ptr_array_new_with_free_func ((GDestroyNotify) apex_print_free);
  JsonBuilder *b;
  guint i, n = prints ? json_array_get_length (prints) : 0;

  S.match_min = member_int (params, "match_min", S.match_min);
  S.sign_in_min = member_int (params, "sign_in_min", S.sign_in_min);
  S.margin = member_int (params, "margin", S.margin);

  b = ev ("gallery", NULL);
  json_builder_set_member_name (b, "skipped");
  json_builder_begin_array (b);
  for (i = 0; i < n; i++)
    {
      JsonObject *p = json_array_get_object_element (prints, i);
      g_autofree gchar *id = p ? member_id (p, "id") : NULL;
      g_autofree gchar *user = p ? member_id (p, "user_id") : NULL;
      const gchar *b64 = p ? member_str (p, "print") : NULL;
      g_autofree guchar *bytes = NULL;
      gsize length = 0;
      ApexPrint *print = NULL;

      if (id && user && b64)
        {
          bytes = g_base64_decode (b64, &length);
          print = apex_print_new (id, user, bytes, length, NULL);
        }
      if (print)
        g_ptr_array_add (gallery, print);
      else
        json_builder_add_string_value (b, id ? id : "?");
    }
  json_builder_end_array (b);
  g_ptr_array_unref (S.gallery);
  S.gallery = gallery;
  put_int (b, "loaded", S.gallery->len);
  send_event (b);
}

static gboolean
begin (OpKind kind, JsonObject *o)
{
  const gchar *req = member_str (o, "req");

  if (S.op != OP_NONE)
    {
      send_error (req, "BUSY", "The reader is busy: cancel first.");
      return FALSE;
    }
  S.op = kind;
  S.req = g_strdup (req ? req : "");
  return TRUE;
}

static void
cmd_cancel (void)
{
  if (S.op == OP_NONE)
    {
      send_event (ev ("idle", NULL));
      return;
    }
  if (S.pause_source)
    {
      g_source_remove (S.pause_source);
      S.pause_source = 0;
      op_finish (TRUE);
      return;
    }
  S.cancel_requested = TRUE;
  if (S.cancel)
    g_cancellable_cancel (S.cancel);
}

static void
handle_line (const gchar *line)
{
  g_autoptr(JsonParser) parser = json_parser_new ();
  g_autoptr(GError) error = NULL;
  JsonNode *root;
  JsonObject *o;
  const gchar *cmd;

  if (!json_parser_load_from_data (parser, line, -1, &error))
    {
      send_error (NULL, "BAD_CMD", error->message);
      return;
    }
  root = json_parser_get_root (parser);
  if (root == NULL || JSON_NODE_TYPE (root) != JSON_NODE_OBJECT)
    {
      send_error (NULL, "BAD_CMD", "A command is a JSON object.");
      return;
    }
  o = json_node_get_object (root);
  cmd = member_str (o, "cmd");

  if (g_strcmp0 (cmd, "status") == 0)
    send_reader ();
  else if (g_strcmp0 (cmd, "gallery") == 0)
    cmd_gallery (o);
  else if (g_strcmp0 (cmd, "scan") == 0)
    {
      if (begin (OP_SCAN, o))
        {
          S.sign_in = g_strcmp0 (member_str (o, "purpose"), "sign_in") == 0;
          S.all_scores = member_bool (o, "all_scores");
          arm_timeout (o, SCAN_TIMEOUT);
          start_identify ();
        }
    }
  else if (g_strcmp0 (cmd, "enroll") == 0)
    {
      if (begin (OP_ENROLL, o))
        {
          S.user_id = member_id (o, "user_id");
          S.finger = finger_of (member_str (o, "finger"));
          arm_timeout (o, ENROLL_TIMEOUT);
          start_enroll ();
        }
    }
  else if (g_strcmp0 (cmd, "verify") == 0)
    {
      const gchar *b64 = member_str (o, "print");
      g_autofree guchar *bytes = NULL;
      gsize length = 0;

      if (!begin (OP_VERIFY, o))
        return;
      S.user_id = member_id (o, "user_id");
      if (b64)
        bytes = g_base64_decode (b64, &length);
      S.target = apex_print_new ("verify", S.user_id ? S.user_id : "", bytes, length, &error);
      if (S.target == NULL)
        {
          send_error (S.req, "BAD_PRINT", error ? error->message : "no print");
          op_finish (FALSE);
          return;
        }
      arm_timeout (o, SCAN_TIMEOUT);
      start_identify ();
    }
  else if (g_strcmp0 (cmd, "cancel") == 0)
    cmd_cancel ();
  else if (g_strcmp0 (cmd, "quit") == 0)
    g_main_loop_quit (S.loop);
  else
    send_error (member_str (o, "req"), "BAD_CMD", cmd ? cmd : "no cmd");
}

static gboolean
on_stdin (GIOChannel *channel, GIOCondition condition, gpointer data)
{
  for (;;)
    {
      g_autofree gchar *line = NULL;
      g_autoptr(GError) error = NULL;
      gsize length = 0;
      GIOStatus status = g_io_channel_read_line (channel, &line, &length, NULL, &error);

      if (status == G_IO_STATUS_NORMAL)
        {
          g_strstrip (line);
          if (*line)
            handle_line (line);
          continue;
        }
      if (status == G_IO_STATUS_AGAIN)
        return G_SOURCE_CONTINUE;
      /* EOF or error: the app is gone. */
      g_main_loop_quit (S.loop);
      return G_SOURCE_REMOVE;
    }
}

static gboolean
on_signal (gpointer data)
{
  g_main_loop_quit (S.loop);
  return G_SOURCE_REMOVE;
}

int
main (int argc, char **argv)
{
  g_autoptr(GIOChannel) in = NULL;
  g_autoptr(GPtrArray) devices = NULL;
  int proto_fd;
  guint i;

  /* Die with the app; the terminal updater only stops apex_pos itself.
   * (Linux; on a Mac, used for checking a reader, stdin's EOF does it.) */
#ifdef __linux__
  prctl (PR_SET_PDEATHSIG, SIGTERM);
#endif

  /* Keep the protocol on the real stdout; anything else written to fd 1
   * (a stray printf, GLib's default handler) lands on stderr instead. */
  proto_fd = dup (STDOUT_FILENO);
  dup2 (STDERR_FILENO, STDOUT_FILENO);
  S.proto = fdopen (proto_fd, "w");
  g_log_set_writer_func (log_to_stderr, NULL, NULL);

  S.loop = g_main_loop_new (NULL, FALSE);
  S.gallery = g_ptr_array_new_with_free_func ((GDestroyNotify) apex_print_free);
  S.match_min = 40;
  S.sign_in_min = 55;
  S.margin = 10;

  in = g_io_channel_unix_new (STDIN_FILENO);
  g_io_channel_set_encoding (in, NULL, NULL);
  g_io_channel_set_flags (in, G_IO_FLAG_NONBLOCK, NULL);
  g_io_add_watch (in, G_IO_IN | G_IO_HUP | G_IO_ERR, on_stdin, NULL);
  g_unix_signal_add (SIGTERM, on_signal, NULL);
  g_unix_signal_add (SIGINT, on_signal, NULL);

  S.ctx = fp_context_new ();
  g_signal_connect (S.ctx, "device-added", G_CALLBACK (on_device_added), NULL);
  g_signal_connect (S.ctx, "device-removed", G_CALLBACK (on_device_removed), NULL);
  devices = g_ptr_array_ref (fp_context_get_devices (S.ctx));
  for (i = 0; i < devices->len; i++)
    open_reader (g_ptr_array_index (devices, i));
  if (S.dev == NULL && S.opening == NULL)
    send_reader ();

  g_main_loop_run (S.loop);

  if (S.cancel)
    g_cancellable_cancel (S.cancel);
  if (S.dev)
    fp_device_close_sync (S.dev, NULL, NULL);
  g_clear_object (&S.dev);
#ifdef __APPLE__
  /* Homebrew's libgusb traps in g_usb_context_dispose on macOS (SIGTRAP at
   * every exit): the reader is closed, so leave without disposing the context. */
  fclose (S.proto);
  _exit (0);
#endif
  g_clear_object (&S.ctx);
  g_ptr_array_unref (S.gallery);
  fclose (S.proto);
  return 0;
}
