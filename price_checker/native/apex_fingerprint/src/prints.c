/* apex_fingerprint — enrolled prints and scoring (see prints.h). */
#include "prints.h"

#include <string.h>

/* libfprint's FPI_PRINT_VARIANT_TYPE (fp-print.c): type, driver, device id,
 * device-stored, finger, user name, description, enrol date, a{sv}, data. */
#define APEX_PRINT_VARIANT "(issbymsmsia{sv}v)"
#define APEX_PRINT_NBIS    2 /* FPI_PRINT_NBIS */
#define APEX_DATA_CHILD    9

static GQuark
apex_print_error_quark (void)
{
  return g_quark_from_static_string ("apex-print-error");
}

static gboolean
fail (GError **error, const gchar *message)
{
  g_set_error_literal (error, apex_print_error_quark (), 1, message);
  return FALSE;
}

gboolean
apex_print_parse (const guchar *data,
                  gsize         length,
                  gchar       **driver,
                  GPtrArray   **subs,
                  GError      **error)
{
  g_autoptr(GVariant) value = NULL;
  g_autoptr(GVariant) boxed = NULL;
  g_autoptr(GVariant) inner = NULL;
  g_autoptr(GVariant) sets = NULL;
  g_autoptr(GPtrArray) out = NULL;
  gint32 type = 0;
  const gchar *drv = NULL;
  gsize n, i;
  guchar *copy;

  /* fp_print_deserialize asserts on fewer than 4 bytes: check first. */
  if (data == NULL || length < 4 || memcmp (data, "FP3", 3) != 0)
    return fail (error, "not a libfprint print");

  copy = g_memdup2 (data + 3, length - 3);
  value = g_variant_ref_sink (g_variant_new_from_data (G_VARIANT_TYPE (APEX_PRINT_VARIANT),
                                                       copy, length - 3, FALSE,
                                                       g_free, copy));
  g_variant_get_child (value, 0, "i", &type);
  g_variant_get_child (value, 1, "&s", &drv);
  if (type != APEX_PRINT_NBIS)
    return fail (error, "not an image-reader (NBIS) print");

  boxed = g_variant_get_child_value (value, APEX_DATA_CHILD);
  inner = g_variant_get_variant (boxed);
  if (!g_variant_is_of_type (inner, G_VARIANT_TYPE ("(a(aiaiai))")))
    return fail (error, "print data has an unknown shape");

  sets = g_variant_get_child_value (inner, 0);
  n = g_variant_n_children (sets);
  if (n == 0)
    return fail (error, "print has no minutiae");

  out = g_ptr_array_new_with_free_func (g_free);
  for (i = 0; i < n; i++)
    {
      g_autoptr(GVariant) set = g_variant_get_child_value (sets, i);
      g_autoptr(GVariant) xs = g_variant_get_child_value (set, 0);
      g_autoptr(GVariant) ys = g_variant_get_child_value (set, 1);
      g_autoptr(GVariant) ts = g_variant_get_child_value (set, 2);
      gsize nx, ny, nt;
      const gint32 *x = g_variant_get_fixed_array (xs, &nx, sizeof (gint32));
      const gint32 *y = g_variant_get_fixed_array (ys, &ny, sizeof (gint32));
      const gint32 *t = g_variant_get_fixed_array (ts, &nt, sizeof (gint32));
      struct xyt_struct *xyt;

      if (nx != ny || nx != nt)
        return fail (error, "print minutiae columns differ in length");
      if (nx > MAX_BOZORTH_MINUTIAE)
        return fail (error, "print has too many minutiae");

      xyt = g_new0 (struct xyt_struct, 1);
      xyt->nrows = (int) nx;
      memcpy (xyt->xcol, x, nx * sizeof (gint32));
      memcpy (xyt->ycol, y, nx * sizeof (gint32));
      memcpy (xyt->thetacol, t, nx * sizeof (gint32));
      g_ptr_array_add (out, xyt);
    }

  if (driver)
    *driver = g_strdup (drv);
  if (subs)
    *subs = g_steal_pointer (&out);
  return TRUE;
}

ApexPrint *
apex_print_new (const gchar  *id,
                const gchar  *user_id,
                const guchar *data,
                gsize         length,
                GError      **error)
{
  ApexPrint *print;
  gchar *driver = NULL;
  GPtrArray *subs = NULL;

  if (!apex_print_parse (data, length, &driver, &subs, error))
    return NULL;

  print = g_new0 (ApexPrint, 1);
  print->id = g_strdup (id);
  print->user_id = g_strdup (user_id);
  print->driver = driver;
  print->subs = subs;
  return print;
}

void
apex_print_free (ApexPrint *print)
{
  if (print == NULL)
    return;
  g_free (print->id);
  g_free (print->user_id);
  g_free (print->driver);
  g_clear_pointer (&print->subs, g_ptr_array_unref);
  g_free (print);
}

int
apex_probe_init (struct xyt_struct *probe)
{
  return bozorth_probe_init (probe);
}

int
apex_best_score (int                probe_len,
                 struct xyt_struct *probe,
                 GPtrArray         *subs,
                 int                enough)
{
  int best = 0;
  guint i;

  for (i = 0; i < subs->len; i++)
    {
      int score = bozorth_to_gallery (probe_len, probe, g_ptr_array_index (subs, i));

      if (score > best)
        best = score;
      if (enough > 0 && best >= enough)
        break;
    }
  return best;
}

gboolean
apex_subs_consistent (GPtrArray *subs,
                      int        min,
                      int       *weakest)
{
  guint n = subs->len, i, j;
  g_autofree gboolean *linked = g_new0 (gboolean, (gsize) n * n);
  g_autofree gboolean *seen = g_new0 (gboolean, n);
  g_autofree guint *stack = g_new0 (guint, n);
  guint top = 0, reached = 0;
  int weakest_best = G_MAXINT;

  if (n < 2)
    {
      if (weakest)
        *weakest = 0;
      return n == 1;
    }

  g_autofree int *best = g_new0 (int, n);

  /* Each pair once: bozorth3 scores a pair about the same either way round. */
  for (i = 0; i + 1 < n; i++)
    {
      struct xyt_struct *probe = g_ptr_array_index (subs, i);
      int len = bozorth_probe_init (probe);

      for (j = i + 1; j < n; j++)
        {
          int score = bozorth_to_gallery (len, probe, g_ptr_array_index (subs, j));

          best[i] = MAX (best[i], score);
          best[j] = MAX (best[j], score);
          if (score >= min)
            linked[i * n + j] = linked[j * n + i] = TRUE;
        }
    }
  for (i = 0; i < n; i++)
    weakest_best = MIN (weakest_best, best[i]);

  /* One group: every press reachable from the first through good scores. */
  stack[top++] = 0;
  seen[0] = TRUE;
  while (top > 0)
    {
      guint k = stack[--top];

      reached++;
      for (j = 0; j < n; j++)
        if (linked[k * n + j] && !seen[j])
          {
            seen[j] = TRUE;
            stack[top++] = j;
          }
    }

  if (weakest)
    *weakest = weakest_best;
  return reached == n && weakest_best >= min;
}
