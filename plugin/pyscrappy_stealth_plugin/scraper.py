import os
import httpx
from pyscrappy import BaseScraper, register_scraper
from pyscrappy.core.models import ScrapeResult, ScrapeMetadata

@register_scraper("stealth_browser")
class StealthBrowserScraper(BaseScraper):
    """
    A specialized proxy scraper. 
    Delegates anti-detection tasks to a remote stealth-browser-mcp service.
    """

    def __init__(self):
        # The URL of the remote stealth-browser container
        self.remote_url = os.getenv("STEALTH_BROWSER_URL", "http://stealth-browser:8000")
        # IMPORTANT: We must also grab the token to authenticate our request
        self.stealth_token = os.getenv("STEALTH_TOKEN")

    async def scrape(self, url: str, **kwargs) -> ScrapeResult:
        """
        Delegates the navigation and extraction to the remote stealth service.
        """
        # Prepare headers for authentication
        headers = {}
        if self.stealth_token:
            headers["Authorization"] = f"Bearer {self.stealth_token}"

        async with httpx.AsyncClient(timeout=120.0) as client:
            # Construct the JSON-RPC payload for the MCP server
            payload = {
                "jsonrpc": "2.0",
                "method": "tools/call",
                "params": {
                    "name": "navigate", 
                    "arguments": {
                        "url": url,
                        **kwargs
                    }
                },
                "id": 1
            }

            try:
                # We pass the headers here!
                response = await client.post(
                    f"{self.remote_url}/mcp", 
                    json=payload, 
                    headers=headers
                )
                response.raise_for_status()
                
                mcp_data = response.json()
                
                # Extract content from the MCP response structure
                content = mcp_data.get("result", {}).get("content", [])

                return ScrapeResult(
                    data=content,
                    metadata=ScrapeMetadata(
                        scraper="stealth_browser_remote",
                        extra={"remote_status": response.status_code}
                    )
                )

            except Exception as e:
                print(f"[ERROR] [StealthPlugin] Connection error to {self.remote_url}: {str(e)}")
                raise e
