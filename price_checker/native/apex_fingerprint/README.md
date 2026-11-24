# apex_fingerprint (copy)

**A copy — change it in `apex_pos/native/apex_fingerprint`, then run
`./sync_from_pos.sh` here.** The fingerprint reader program the Apex POS and
this kiosk share: a DigitalPersona U.are.U 4500 through libfprint, matched by
NIST bozorth3. Its protocol is at the top of `src/main.c`; its tests live in
the POS repo (`native/apex_fingerprint/test/run_tests.sh`).

Built by `linux/CMakeLists.txt` when `libfprint-2-dev` and `libjson-glib-dev`
are installed, and installed next to the app (`price_checker`). On the kiosk
PC: `setup_terminal.sh --fingerprint` from the POS bundle folder, once.
