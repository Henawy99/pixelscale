import modal
import os

app = modal.App("test-roboflow-download")
image = modal.Image.debian_slim().pip_install("roboflow")

@app.local_entrypoint()
def main():
    test_download.remote()

@app.function(image=image)
def test_download():
    from roboflow import Roboflow
    rf = Roboflow(api_key="TsZ58QXSmc6pkBSsklrJ")
    project = rf.workspace("playmaker-eftm1").project("soccer-ball-tracker-sgt32")
    model = project.version(4).model
    
    import glob
    formats_to_try = ["yolov8", "pt", "pytorch", "weights", "torch"]
    for fmt in formats_to_try:
        print(f"\n--- Testing format: {fmt} ---")
        try:
            model.download(fmt)
            print(f"✅ Success with {fmt}")
            print(f"Files in current dir: {glob.glob('*')}")
            print(f"Files in subdirs: {glob.glob('*/*')}")
            for root, dirs, files in os.walk("."):
                for name in files:
                    if name.endswith(".pt"):
                        print(f"⚽ Found .pt file: {os.path.join(root, name)}")
            return
        except Exception as e:
            print(f"❌ Failed with {fmt}: {e}")
