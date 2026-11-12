import Image from "next/image";

type PhoneFrameProps = {
  src: string;
  alt: string;
  priority?: boolean;
  className?: string;
};

export function PhoneFrame({
  src,
  alt,
  priority = false,
  className,
}: PhoneFrameProps) {
  return (
    <div
      className={`relative aspect-[9/19] overflow-hidden rounded-[2rem] bg-card shadow-lg ring-1 ring-outline/20 ${className ?? ""}`}
    >
      <Image
        src={src}
        alt={alt}
        fill
        priority={priority}
        sizes="(max-width: 768px) 70vw, 280px"
        className="object-cover object-top"
      />
    </div>
  );
}
