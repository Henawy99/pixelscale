-- Create table to store FCM device tokens for push notifications
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token TEXT NOT NULL UNIQUE,
  device_id TEXT,
  platform TEXT, -- 'ios', 'android', 'web'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

-- Policy: Allow anyone to insert their own token
CREATE POLICY "Allow token registration" ON public.device_tokens
  FOR INSERT
  WITH CHECK (true);

-- Policy: Allow updating tokens
CREATE POLICY "Allow token updates" ON public.device_tokens
  FOR UPDATE
  USING (true);

-- Create index on token for faster lookups
CREATE INDEX IF NOT EXISTS idx_device_tokens_token ON public.device_tokens(token);

-- Create index on updated_at for cleanup queries
CREATE INDEX IF NOT EXISTS idx_device_tokens_updated_at ON public.device_tokens(updated_at);

