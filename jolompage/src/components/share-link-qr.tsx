"use client";

import { useSyncExternalStore } from "react";
import { QRCodeSVG } from "qrcode.react";

const subscribe = () => () => undefined;

export function ShareLinkQr() {
  const isBrowser = useSyncExternalStore(subscribe, () => true, () => false);
  const mobileDevice =
    isBrowser && /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
  const shareUrl = isBrowser ? window.location.href : "";
  const isDesktop = isBrowser && !mobileDevice;

  if (!isDesktop || !shareUrl) {
    return (
      <p className="mt-5 text-center text-xs leading-5 text-muted sm:text-left">
        ¿Ya instalaste Jolom? Vuelve al mensaje donde recibiste este enlace y
        tócalo nuevamente.
      </p>
    );
  }

  return (
    <div className="mt-8 flex items-center gap-5 rounded-2xl border border-outline/20 bg-background/70 p-4">
      <div className="shrink-0 rounded-xl bg-white p-2 shadow-sm">
        <QRCodeSVG
          value={shareUrl}
          size={120}
          level="M"
          marginSize={1}
          title="Código QR para abrir este enlace de Jolom"
        />
      </div>
      <div>
        <p className="font-semibold text-foreground">Ábrelo en tu teléfono</p>
        <p className="mt-1 text-sm leading-6 text-muted">
          Escanea el código con la cámara para abrir Jolom o descargar la app.
        </p>
      </div>
    </div>
  );
}
