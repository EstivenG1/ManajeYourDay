ALTER TABLE public.presupuestos
ADD COLUMN IF NOT EXISTS emoji text NOT NULL DEFAULT '💰';
