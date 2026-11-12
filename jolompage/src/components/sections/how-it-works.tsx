import { PhoneFrame } from "@/components/phone-frame";
import { howItWorksScreenshots, showScreenshots } from "@/content/screenshots";
import { howItWorks } from "@/content/site";

export function HowItWorks() {
  return (
    <section id="como-funciona" className="px-6 py-24">
      <div className="mx-auto w-full max-w-6xl">
        <h2 className="text-3xl font-semibold tracking-tight sm:text-4xl">
          {howItWorks.title}
        </h2>

        <ol className="mt-14 grid gap-12 sm:grid-cols-3">
          {howItWorks.steps.map((step, index) => {
            const shot = howItWorksScreenshots[index];

            return (
              <li key={step.id} className="flex flex-col">
                <span
                  className="text-sm font-medium text-brand"
                  aria-hidden="true"
                >
                  {String(index + 1).padStart(2, "0")}
                </span>
                <h3 className="mt-4 text-lg font-medium text-foreground">
                  {step.title}
                </h3>
                <p className="mt-2 text-muted text-pretty">{step.description}</p>
                {showScreenshots && shot ? (
                  <PhoneFrame
                    src={shot.src}
                    alt={shot.alt}
                    className="mt-6 w-full max-w-[220px]"
                  />
                ) : null}
              </li>
            );
          })}
        </ol>
      </div>
    </section>
  );
}
