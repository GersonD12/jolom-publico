import { PhoneFrame } from "@/components/phone-frame";
import { StoreButtons } from "@/components/store-buttons";
import { screenshots, showScreenshots } from "@/content/screenshots";
import { hero } from "@/content/site";

export function Hero() {
  return (
    <section
      id="inicio"
      className="relative flex min-h-[calc(100svh-4rem)] flex-col justify-center overflow-hidden px-6 py-16"
    >
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,_var(--primary-container)_0%,_transparent_55%)] opacity-80" />

      <div className={`relative mx-auto grid w-full max-w-6xl items-center gap-12 ${showScreenshots ? "lg:grid-cols-2" : ""}`}>
        <div>
          <p className="mb-4 text-sm font-medium tracking-wide text-brand">
            Jolom · Guatemala
          </p>
          <h1 className="max-w-xl text-4xl font-semibold tracking-tight text-balance text-foreground sm:text-5xl lg:text-6xl">
            {hero.headline}
          </h1>
          <p className="mt-6 max-w-xl text-lg text-muted text-pretty">
            {hero.subcopy}
          </p>
          <StoreButtons className="mt-10 flex flex-wrap gap-3" />
        </div>

        {showScreenshots && (
          <div id="mockup" className="relative mx-auto w-full max-w-xs">
            <PhoneFrame
              src={screenshots.inicio.src}
              alt={screenshots.inicio.alt}
              priority
              className="animate-float"
            />
          </div>
        )}
      </div>
    </section>
  );
}
