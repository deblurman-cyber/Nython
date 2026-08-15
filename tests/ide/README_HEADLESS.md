# Running GUI / IDE tests headlessly

The GUI and IDE examples drive an SDL3 event loop. Under a real window manager
the loop exits when the user closes the window; with no display attached
`SDL_PollEvent` never returns a quit and the loop spins forever, so these files
used to hang the test sweep and were simply excluded from it.

The headless SDL3 stub used for CI accepts:

    NY_STUB_AUTOQUIT=<n>

After `n` polls that would otherwise return "no events", the stub synthesises a
single `SDL_EVENT_QUIT`, which lets the application shut down through its normal
path. `n` around 150 is a good default: large enough that startup and the first
frames run, small enough to keep the suite quick.

    NY_STUB_AUTOQUIT=150 ./nython examples/nython_ide.ny
    NY_STUB_AUTOQUIT=150 ./nython --vm examples/gui_tests/test_12_ide_launch.ny

The quit is delivered **once** and then latched off. This matters: an event that
re-fires on every poll makes an application's `while (SDL_PollEvent(&e))` drain
loop never terminate. An earlier unlatched version of this feature drove the IDE
to 3.8 GB and an OOM kill — a defect in the test stub, not in the IDE, but one
that looked exactly like an IDE memory leak until it was tracked down.

Without the variable set, the stub behaves as before (no synthetic events), so
existing interactive use is unaffected.
