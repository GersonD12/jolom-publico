import { stores } from "@/content/site";

type StoreButtonsProps = {
  className?: string;
};

export function StoreButtons({ className }: StoreButtonsProps) {
  return (
    <div className={className}>
      <a
        href={stores.appStore.href}
        target="_blank"
        rel="noreferrer"
        aria-label="Descargar Jolom en App Store"
        className="inline-flex items-center gap-3 rounded-xl bg-foreground px-5 py-3 text-background transition-opacity hover:opacity-90"
      >
        <AppleIcon />
        <span className="text-left leading-tight">
          <span className="block text-[10px] opacity-80">Descargar en</span>
          <span className="block text-sm font-semibold tracking-tight">
            {stores.appStore.label}
          </span>
        </span>
      </a>
      <a
        href={stores.googlePlay.href}
        target="_blank"
        rel="noreferrer"
        aria-label="Descargar Jolom en Google Play"
        className="inline-flex items-center gap-3 rounded-xl bg-foreground px-5 py-3 text-background transition-opacity hover:opacity-90"
      >
        <PlayIcon />
        <span className="text-left leading-tight">
          <span className="block text-[10px] opacity-80">Disponible en</span>
          <span className="block text-sm font-semibold tracking-tight">
            {stores.googlePlay.label}
          </span>
        </span>
      </a>
    </div>
  );
}

function AppleIcon() {
  return (
    <svg
      aria-hidden="true"
      viewBox="0 0 24 24"
      className="h-7 w-7 fill-current"
    >
      <path d="M16.7 12.6c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.2-2.8.9-3.5.9-.7 0-1.9-.8-3.1-.8-1.6 0-3.1 1-3.9 2.4-1.7 2.9-.4 7.2 1.2 9.6.8 1.1 1.7 2.4 3 2.4 1.2 0 1.6-.8 3.1-.8s1.8.8 3.1.8c1.3 0 2.1-1.1 2.9-2.2.9-1.3 1.3-2.5 1.3-2.6-.1 0-2.5-1-2.5-3.8zM14.7 5.8c.6-.8 1.1-1.9.9-3-.9 0-2 .6-2.6 1.4-.6.7-1.1 1.8-.9 2.9 1 .1 2-.5 2.6-1.3z" />
    </svg>
  );
}

function PlayIcon() {
  return (
    <svg
      aria-hidden="true"
      viewBox="0 0 24 24"
      className="h-7 w-7 fill-current"
    >
      <path d="M3.6 2.8c-.3.2-.6.6-.6 1.1v16.2c0 .5.3.9.6 1.1l.1.1 9.1-9.1v-.4L3.7 2.7l-.1.1zm11.3 6.4-2.1 2.1 2.1 2.1 4.9-2.8c.6-.3.6-.9 0-1.2l-4.9-2.8v2.6zM13.7 13.4l-2.2 2.2 3.1 3.1c.8.5 1.4.2 1.4-.7v-6.1l-2.3 1.5zm-2.2-5L8.4 5.3 4.8 3.2c-.2-.1-.3-.1-.5 0l7.2 7.2 2.1-2.1-2.1-2.5z" />
    </svg>
  );
}
