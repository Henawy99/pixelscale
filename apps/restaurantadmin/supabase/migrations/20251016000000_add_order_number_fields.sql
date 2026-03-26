-- Add order_number and daily_order_number fields to orders table
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS order_number TEXT,
ADD COLUMN IF NOT EXISTS daily_order_number INTEGER;

-- Create an index on order_number for faster lookups
CREATE INDEX IF NOT EXISTS idx_orders_order_number ON orders(order_number);

-- Create an index on daily_order_number for filtering
CREATE INDEX IF NOT EXISTS idx_orders_daily_order_number ON orders(daily_order_number);

-- Add a comment to document the order_number format
COMMENT ON COLUMN orders.order_number IS 'Custom order ID format: DDMMYYYYTTTTTTNN where DD=day, MM=month, YYYY=year, TTTTTT=total order count, NN=daily order number';
COMMENT ON COLUMN orders.daily_order_number IS 'Daily order number (1-99) extracted from order_number for easy display';

