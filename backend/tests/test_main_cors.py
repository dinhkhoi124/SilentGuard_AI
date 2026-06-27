import sys
from unittest.mock import patch
from fastapi.testclient import TestClient

def test_cors_development():
    # Mock settings to represent development
    with patch("app.core.config.settings.APP_ENV", "development"), \
         patch("app.core.config.settings.CORS_ORIGINS", ""):
        # Reload app module to apply patched settings
        if "app.main" in sys.modules:
            del sys.modules["app.main"]
        from app.main import app
        
        client = TestClient(app)
        # Test options request (CORS preflight)
        response = client.options(
            "/health",
            headers={
                "Origin": "https://example.com",
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "content-type",
            }
        )
        # In dev/development, allow_origins=["*"] which supports any origin
        assert response.headers.get("access-control-allow-origin") == "https://example.com" or response.headers.get("access-control-allow-origin") == "*"

def test_cors_production_default():
    # Mock settings to represent production with no custom CORS_ORIGINS
    with patch("app.core.config.settings.APP_ENV", "production"), \
         patch("app.core.config.settings.CORS_ORIGINS", ""):
        if "app.main" in sys.modules:
            del sys.modules["app.main"]
        from app.main import app
        
        client = TestClient(app)
        
        # Request with trusted origin
        response = client.options(
            "/health",
            headers={
                "Origin": "https://silentguard.ai",
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "content-type",
            }
        )
        assert response.headers.get("access-control-allow-origin") == "https://silentguard.ai"
        
        # Request with untrusted origin
        response = client.options(
            "/health",
            headers={
                "Origin": "https://attacker.com",
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "content-type",
            }
        )
        assert response.headers.get("access-control-allow-origin") is None

def test_cors_production_custom():
    # Mock settings to represent production with custom CORS_ORIGINS
    with patch("app.core.config.settings.APP_ENV", "production"), \
         patch("app.core.config.settings.CORS_ORIGINS", "https://custom.silentguard.ai, https://another.com"):
        if "app.main" in sys.modules:
            del sys.modules["app.main"]
        from app.main import app
        
        client = TestClient(app)
        
        # Request with trusted origin
        response = client.options(
            "/health",
            headers={
                "Origin": "https://custom.silentguard.ai",
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "content-type",
            }
        )
        assert response.headers.get("access-control-allow-origin") == "https://custom.silentguard.ai"
        
        # Request with another trusted origin
        response = client.options(
            "/health",
            headers={
                "Origin": "https://another.com",
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "content-type",
            }
        )
        assert response.headers.get("access-control-allow-origin") == "https://another.com"
        
        # Request with untrusted origin
        response = client.options(
            "/health",
            headers={
                "Origin": "https://silentguard.ai",
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "content-type",
            }
        )
        assert response.headers.get("access-control-allow-origin") is None
