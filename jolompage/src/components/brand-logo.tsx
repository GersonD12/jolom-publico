import Image from "next/image";

type BrandLogoProps = {
  size?: number;
  className?: string;
  priority?: boolean;
};

export function BrandLogo({
  size = 36,
  className,
  priority = false,
}: BrandLogoProps) {
  return (
    <Image
      src="/images/icon.png"
      alt="Jolom"
      width={size}
      height={size}
      priority={priority}
      className={className}
    />
  );
}
