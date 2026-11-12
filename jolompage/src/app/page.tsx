import { Benefits } from "@/components/sections/benefits";
import { FinalCta } from "@/components/sections/final-cta";
import { ForSalons } from "@/components/sections/for-salons";
import { Hero } from "@/components/sections/hero";
import { HowItWorks } from "@/components/sections/how-it-works";
import { Screenshots } from "@/components/sections/screenshots";
import { showScreenshots } from "@/content/screenshots";

export default function HomePage() {
  return (
    <>
      <Hero />
      <Benefits />
      <HowItWorks />
      {showScreenshots && <Screenshots />}
      <ForSalons />
      <FinalCta />
    </>
  );
}
