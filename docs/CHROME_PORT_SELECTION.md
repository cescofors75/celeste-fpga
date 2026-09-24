# Chrome serial-port selection

The serial worker formerly selected a port solely by USB vendor/product IDs.
When two authorized interfaces share those IDs, it rejected even an explicit
selection with “No se puede identificar una única placa autorizada”. Different
browser profiles can therefore behave differently with the same Tang.

The unique-ID path still opens the port directly in the worker. When IDs are
ambiguous, the main thread opens the exact `SerialPort` returned by the chooser
and transfers its readable/writable streams to the worker. No enumeration-order
guess, alternate-device probing or permission deletion is used. The CELESTE
protocol handshake is still mandatory before reporting a connection.

Protocol encoding and PCM scheduling stay in the worker. The ambiguous-port
path uses transferable-stream proxies, whose underlying serial streams belong
to the page; this is not a claim of identical scheduling isolation to a port
opened directly inside the worker. Disconnect waits for stream locks to release
before closing the physical port, allowing reconnection.

`node scripts/test-serial-selection-browser.mjs` uses a real Chromium worker and
transferable streams with two simulated ports sharing IDs. It verifies exact
selection, handshake, stream cleanup, reconnection, invalid device rejection,
and no fallback to another port when the selected port is busy. This is browser
regression coverage, not physical verification in the user's Chrome profile.
