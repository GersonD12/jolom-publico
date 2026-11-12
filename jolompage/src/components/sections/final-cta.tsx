import { StoreButtons } from "@/components/store-buttons";
import { finalCta } from "@/content/site";

export function FinalCta() {
  return (
    <section id="descargar" className="bg-primary-container px-6 py-24">
      <div className="mx-auto w-full max-w-6xl text-center">
        <h2 className="text-3xl font-semibold tracking-tight text-balance sm:text-4xl">
          {finalCta.title}
        </h2>
        <p className="mx-auto mt-4 max-w-xl text-muted text-pretty">
          {finalCta.description}
        </p>
        <StoreButtons className="mt-10 flex flex-wrap justify-center gap-3" />
      </div>
    </section>
  );
}
