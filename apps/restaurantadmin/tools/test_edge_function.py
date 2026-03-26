import base64, json, sys, requests, os

# Project: RestaurantAdmin
SUPABASE_URL = "https://iluhlynzkgubtaswvgwt.supabase.co"
FUNCTION_NAME = "scan-receipt"
EDGE_URL = f"{SUPABASE_URL}/functions/v1/{FUNCTION_NAME}"

# Get a user JWT (not the service role key). Paste here or set as env var AUTH_TOKEN.
AUTH_TOKEN = os.environ.get("AUTH_TOKEN") or "PASTE_USER_JWT_HERE"

def send_image(image_path, brand_id=None, brand_name=None, platform_order_id=None, idempotency_key=None):
    with open(image_path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode("utf-8")
    payload = {
        "receiptImageBase64": b64,
    }
    if brand_id: payload["brandId"] = brand_id
    if brand_name: payload["brandName"] = brand_name
    if platform_order_id: payload["platformOrderId"] = platform_order_id
    if idempotency_key: payload["idempotencyKey"] = idempotency_key

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {AUTH_TOKEN}",
    }
    r = requests.post(EDGE_URL, data=json.dumps(payload), headers=headers, timeout=60)
    print("Status:", r.status_code)
    try:
        print(json.dumps(r.json(), indent=2))
    except Exception:
        print(r.text)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python tools/test_edge_function.py path/to/receipt.jpg")
        sys.exit(1)
    path = sys.argv[1]
    # Default brand for quick test; override with -- brand params in send_image if needed
    send_image(path, scan_type=stype, brand_name="DEVILS SMASH BURGER")