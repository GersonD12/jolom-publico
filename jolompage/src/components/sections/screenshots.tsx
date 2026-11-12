import { PhoneFrame } from "@/components/phone-frame";
import { clientScreenshots } from "@/content/screenshots";
import { screenshotsSection } from "@/content/site";

export function Screenshots() {
  return (
    <section id="capturas" className="overflow-hidden bg-surface-secondary px-6 py-24">
      <div className="mx-auto w-full max-w-6xl">
        <h2 className="text-3xl font-semibold tracking-tight sm:text-4xl">
          {screenshotsSection.title}
        </h2>
        <p className="mt-4 max-w-2xl text-muted text-pretty">
          {screenshotsSection.description}
        </p>

        <div
          className="mt-14 flex gap-6 overflow-x-auto pb-4"
          aria-label="Capturas de la aplicación"
        >
          {clientScreenshots.map((shot) => (
            <PhoneFrame
              key={shot.src}
              src={shot.src}
              alt={shot.alt}
              className="w-56 shrink-0"
            />
          ))}
        </div>
      </div>
    </section>
  );
}
