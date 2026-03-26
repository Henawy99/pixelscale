# Order ID System and Delivery Monitor Implementation

## Overview
This implementation adds a custom order ID system with the format `DDMMYYYYTTTTTTNN` and enhances the delivery monitor screen to display order markers on the map.

## Order ID Format
- **DD**: Day (2 digits)
- **MM**: Month (2 digits)  
- **YYYY**: Year (4 digits)
- **TTTTTT**: Total order count (6 digits, zero-padded)
- **NN**: Daily order number (2 digits, zero-padded)

**Example**: `18102025250006` = October 18, 2025, 2500th total order, 6th order of the day

## Files Created

### 1. `lib/services/order_id_service.dart`
- Service for generating custom order IDs
- Methods:
  - `generateOrderId()`: Creates unique order ID with daily and total count
  - `extractDailyOrderNumber()`: Extracts daily number from order ID
  - `extractDate()`: Extracts date from order ID
  - `formatForDisplay()`: Formats order ID with dashes for readability

### 2. `supabase/migrations/20251016000000_add_order_number_fields.sql`
- Adds `order_number` (TEXT) column to orders table
- Adds `daily_order_number` (INTEGER) column to orders table
- Creates indexes for both fields for performance
- Includes documentation comments

### 3. `apply_migration.sql`
- Standalone SQL file to apply the migration manually if needed

## Files Modified

### 1. `lib/models/order.dart`
- Added `orderNumber` field (String?)
- Added `dailyOrderNumber` field (int?)
- Updated `toJson()` to include new fields
- Updated `fromJson()` to parse new fields

### 2. `lib/services/order_service.dart`
- **`createOrderFromCart()`**: Now generates custom order ID for manual orders
- **`createOrderFromScannedData()`**: Now generates custom order ID for scanned orders
- Both methods use `OrderIdService` to generate unique IDs

### 3. `supabase/functions/scan-receipt/index.ts`
- Added `generateCustomOrderId()` function for Edge Function order creation
- **`insertOrder()`**: Now generates and saves custom order number and daily order number
- Order ID generation happens server-side for scanned receipts

### 4. `lib/screens/delivery_monitor_screen.dart`
- **New Features**:
  - Fetches orders with delivery coordinates
  - Creates custom orange markers with daily order number
  - Displays both driver markers (blue) and order markers (orange)
  - Real-time updates for both drivers and orders
  - Shows count of online drivers and active orders in header

- **New Methods**:
  - `_fetchDeliveryOrders()`: Fetches orders with coordinates
  - `_createCustomOrderMarker()`: Creates orange circular marker with order number
  - Updated `_updateMapMarkers()`: Now includes both driver and order markers

- **UI Updates**:
  - Two badges in AppBar: blue for drivers, orange for orders
  - Refresh button updates both drivers and orders
  - Order markers show: Order #(daily number), customer name, address, and price

## How It Works

### Order Creation Flow

#### Manual Orders (Cart):
1. User creates order through cart
2. `OrderService.createOrderFromCart()` is called
3. `OrderIdService.generateOrderId()` queries database for counts
4. Generates order ID: `DDMMYYYYTTTTTTNN`
5. Order saved with `order_number` and `daily_order_number`

#### Scanned Orders (PowerShell Watcher):
1. Receipt scanned and sent to Edge Function
2. Edge Function `scan-receipt` receives image
3. `generateCustomOrderId()` queries database for counts
4. Generates order ID: `DDMMYYYYTTTTTTNN`
5. Order inserted with custom ID fields
6. Order appears in orders screen and delivery monitor

### Delivery Monitor Display

1. **On Load**:
   - Fetches online drivers with GPS coordinates
   - Fetches orders with delivery coordinates (not null)
   - Filters orders by status: pending_confirmation, confirmed, preparing, ready_to_deliver, out_for_delivery

2. **Marker Creation**:
   - **Blue markers**: Drivers with their initial letter
   - **Orange markers**: Orders with their daily number (6, 7, 8, etc.)

3. **Real-time Updates**:
   - Subscribed to `drivers` table changes
   - Subscribed to `orders` table changes
   - Map refreshes automatically when data changes

## Database Migration

To apply the migration to add `order_number` and `daily_order_number` columns:

```sql
-- Run the apply_migration.sql file in your Supabase SQL Editor:
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS order_number TEXT,
ADD COLUMN IF NOT EXISTS daily_order_number INTEGER;

CREATE INDEX IF NOT EXISTS idx_orders_order_number ON orders(order_number);
CREATE INDEX IF NOT EXISTS idx_orders_daily_order_number ON orders(daily_order_number);
```

Or use the Supabase dashboard SQL editor to run the contents of:
- `supabase/migrations/20251016000000_add_order_number_fields.sql`

## Benefits

1. **Easy Order Identification**: Commander sees "Order #6" instead of UUID
2. **Daily Reset**: Numbers restart each day (1, 2, 3...)
3. **Unique IDs**: Full order number includes date and total count
4. **Visual Organization**: Orange markers stand out on map
5. **Real-time Updates**: Map refreshes as new orders arrive
6. **Historical Tracking**: Total order count embedded in ID

## Testing

1. **Create Manual Order**:
   - Go to cart, add items, checkout
   - Order should have `order_number` like `18102025250006`
   - Check `daily_order_number` is correct (1, 2, 3...)

2. **Scan Receipt**:
   - Use PowerShell watcher to scan receipt
   - Order should appear with custom ID
   - Verify both fields are populated

3. **Delivery Monitor**:
   - Open delivery monitor screen
   - Should see orange markers for orders with coordinates
   - Tap marker to see order details
   - Numbers should match daily order count (6, 7, 8...)

## Notes

- Order IDs are generated at creation time, not on database trigger
- Daily order number is extracted from the full order ID
- The format is fixed-width for easy parsing and sorting
- If database query fails, fallback uses timestamp-based ID
- Orders without coordinates won't appear on delivery monitor
- Only active orders (not completed/cancelled) show on map

