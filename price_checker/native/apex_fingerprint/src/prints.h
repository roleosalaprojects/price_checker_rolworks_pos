/* apex_fingerprint — enrolled prints and scoring.
 *
 * A print is libfprint's own serialized FpPrint ("FP3" + a GVariant). For an
 * image reader such as the U.are.U 4500 (driver uru4000) it holds NBIS
 * minutiae: one x/y/theta set per enrolment press. We read those sets
 * ourselves and score with NIST bozorth3 — the matcher libfprint itself uses —
 * because libfprint's identify returns the FIRST print above its threshold,
 * not the best one, and gives no score.
 */
#pragma once

#include <glib.h>

#include "bozorth.h"

typedef struct
{
  gchar     *id;      /* the server's print id */
  gchar     *user_id; /* whose print */
  gchar     *driver;  /* libfprint driver that made it */
  GPtrArray *subs;    /* struct xyt_struct *, one per press */
} ApexPrint;

/* Reads the driver and the minutiae sets of a serialized print. NBIS only. */
gboolean apex_print_parse (const guchar *data,
                           gsize         length,
                           gchar       **driver,
                           GPtrArray   **subs,
                           GError      **error);

ApexPrint *apex_print_new (const gchar  *id,
                           const gchar  *user_id,
                           const guchar *data,
                           gsize         length,
                           GError      **error);

void apex_print_free (ApexPrint *print);

/* Prepares a probe (one minutiae set); returns its length for apex_score. */
int apex_probe_init (struct xyt_struct *probe);

/* Best bozorth3 score of an initialised probe against any set of @subs.
 * Stops at the first score of @enough or more (0: score them all): a press
 * that plainly matches one set need not be scored against the other four,
 * and a strong genuine comparison is the slowest kind. */
int apex_best_score (int                probe_len,
                     struct xyt_struct *probe,
                     GPtrArray         *subs,
                     int                enough);

/* TRUE when the presses of one enrolment come from one finger: every press
 * scores at least @min against another press and the presses form one group. */
gboolean apex_subs_consistent (GPtrArray *subs,
                               int        min,
                               int       *weakest);
