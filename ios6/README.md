# DTF on iOS 6 — connectivity proof

**Status: the networking wall is broken.** Verified on a real iPhone 3GS (armv7, iOS 6)
on 2026-09-02:

```
[ OK ] 3. TCP connected to api.dtf.ru:443
[ OK ] 4. TLS handshake: TLSv1.2 / TLS-ECDHE-RSA-WITH-AES-128-GCM-SHA256
[ OK ] 5. certificate verified against bundled roots
[ OK ] 7. response: HTTP/1.1 200 OK

>>> received 324588 bytes of feed data
>>> RESULT: SUCCESS — iOS 6 CAN talk to DTF
```

## Why this was needed

`api.dtf.ru` accepts only TLS 1.2 with AES-GCM (TLS 1.0/1.1 and CBC suites are
refused) and its certificate chains to a Let's Encrypt root that does not exist in
the 2012 trust store. iOS 6's own networking therefore cannot reach it at all —
Safari on the device fails the handshake before certificates are even considered,
so anything built on NSURLConnection is dead on arrival.

This probe bypasses the system stack: raw BSD sockets plus a bundled mbedTLS with
the ISRG roots compiled in. No proxy server is involved, so nothing sits between
the device and DTF.

## Files

- `tlstest.c` — the probe; reports each stage separately so a failure says exactly
  which wall was hit.
- `libc_shim.c` — the eight memory/string routines the public SDK stubs don't
  export for armv7.
- `ca_bundle.pem` — ISRG Root YR + ISRG Root X1, embedded into the binary at build.

## Building

No Mac required. `.github/workflows/ios6-probe.yml` cross-compiles on a Linux
runner (Linux-hosted clang/ld64 + iPhoneOS SDK, `-miphoneos-version-min=6.0`,
armv7) and fake-signs with `ldid` for jailbroken devices.

## Running

Copy to the device (3uTools works), then over SSH — note that a modern ssh client
must be told to accept the phone's old host keys:

    ssh -o HostKeyAlgorithms=+ssh-rsa root@<device-ip>
    chmod +x /var/mobile/Media/Downloads/dtf-probe
    /var/mobile/Media/Downloads/dtf-probe
