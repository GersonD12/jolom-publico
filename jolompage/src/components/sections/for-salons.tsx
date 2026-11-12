import { PhoneFrame } from "@/components/phone-frame";
import { salonScreenshots, showScreenshots } from "@/content/screenshots";
import { forSalons } from "@/content/site";

export function ForSalons() {
  return (
    <section id="para-peluquerias" className="px-6 py-24">
      <div className="mx-auto grid w-full max-w-6xl gap-12 lg:grid-cols-[1fr_1.1fr] lg:items-start">
        <div>
          <h2 className="text-3xl font-semibold tracking-tight text-balance sm:text-4xl">
            {forSalons.title}
          </h2>
          <p className="mt-4 max-w-xl text-muted text-pretty">
            {forSalons.description}
          </p>
          <ul className="mt-8 space-y-3">
            {forSalons.points.map((point) => (
              <li key={point} className="flex gap-3 text-foreground">
                <span
                  className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-brand"
                  aria-hidden="true"
                />
                <span>{point}</span>
              </li>
            ))}
          </ul>
        </div>

        {showScreenshots && (
          <div className="flex gap-6 overflow-x-auto pb-4 lg:grid lg:grid-cols-2 lg:overflow-visible">
            {salonScreenshots.map((shot) => (
              <PhoneFrame
                key={shot.src}
                src={shot.src}
                alt={shot.alt}
                className="w-56 shrink-0 lg:w-full"
              />
            ))}
          </div>
        )}
      </div>
    </section>
  );
}
