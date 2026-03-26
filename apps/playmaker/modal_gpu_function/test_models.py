import google.generativeai as genai
import os
import modal

app = modal.App("test-models")
image = modal.Image.debian_slim().pip_install("google-generativeai")

@app.function(image=image, secrets=[modal.Secret.from_name("gemini-api-key")])
def list_models():
    genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))
    print("Listing models...")
    for m in genai.list_models():
        print(f"- {m.name} ({m.supported_generation_methods})")

if __name__ == "__main__":
    with modal.Retrying():
        import modal.runner
        with modal.runner.deploy_app(app):
            pass # just deploy or run?
