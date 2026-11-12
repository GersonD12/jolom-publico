import { benefits } from "@/content/site";

export function Benefits() {
  return (
    <section id="beneficios" className="bg-surface-secondary px-6 py-24">
      <div className="mx-auto w-full max-w-6xl">
        <h2 className="max-w-2xl text-3xl font-semibold tracking-tight text-balance sm:text-4xl">
          {benefits.title}
        </h2>

        <ul className="mt-14 grid gap-10 sm:grid-cols-2 lg:grid-cols-4">
          {benefits.items.map((item) => (
            <li key={item.id}>
              <h3 className="text-lg font-medium text-brand">{item.title}</h3>
              <p className="mt-3 text-muted text-pretty">{item.description}</p>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
