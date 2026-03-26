import modal
import os

app = modal.App("test-roboflow-inference")
image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install("inference-gpu", "supervision==0.18.0", "opencv-python-headless", "numpy")
    .apt_install("libgl1-mesa-glx", "libglib2.0-0")
)

@app.local_entrypoint()
def main():
    test_download.remote()

@app.function(image=image)
def test_download():
    import numpy as np
    import cv2
    from inference import get_model
    
    print("Loading model via inference package...")
    # dummy image
    img = np.zeros((640, 640, 3), dtype=np.uint8)
    try:
        model = get_model(model_id="soccer-ball-tracker-sgt32/4", api_key="TsZ58QXSmc6pkBSsklrJ")
        print("✅ Model loaded successfully!")
        
        results = model.infer(img)
        print("✅ Inference complete. Output format:")
        print(type(results))
        if isinstance(results, list):
            print(results[0])
            for p in results[0].predictions:
                print(vars(p))
                print(dir(p))
                break
        else:
            print(results)
    except Exception as e:
        print(f"❌ Failed: {e}")
