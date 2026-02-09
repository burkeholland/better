type LoadingSpinnerProps = {
  label?: string;
  size?: 'sm' | 'md';
};

const sizeClasses: Record<NonNullable<LoadingSpinnerProps['size']>, string> = {
  sm: 'h-4 w-4 border-2',
  md: 'h-6 w-6 border-[3px]',
};

export default function LoadingSpinner({ label, size = 'md' }: LoadingSpinnerProps) {
  const spinner = (
    <span
      className={`inline-block rounded-full border-slate-300 border-t-slate-600 animate-spin ${sizeClasses[size]}`}
      aria-hidden="true"
    />
  );

  if (!label) {
    return spinner;
  }

  return (
    <div className="flex items-center gap-2 text-slate-600">
      {spinner}
      <span className="text-sm">{label}</span>
    </div>
  );
}
