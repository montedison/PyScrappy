import os
import httpx
from pyscrappy import BaseScraper, register_scraper
from pyscrappy.core.models import ScrapeResult, ScrapeMetadata

@register_scraper("stealth_browser")
class StealthBrowserScraper(BaseScraper):
    """
    A specialized proxy scraper. 
    Instead of scraping locally, it sends a JSON-RPC request 
    to a remote stealth-browser-mcp MCP server via HTTP.
    """

    def __init__(self):
        # The URL of the remote stealth-browser container (service name in Docker)
        self.remote_url = os.getenv("STEALTH_BROWSER_URL", "http://stealth-browser:8000")

    async def scrape(self, url: str, **kwargs) -> ScrapeResult:
        """
        Delegates the navigation and extraction to the remote stealth service.
        """
        # We use the MCP-over-HTTP protocol to call the remote tool
        async with httpx.AsyncClient(timeout=120.0) as client:
            # Construct the JSON-RPC payload for the MCP server
            # We target the 'navigate' tool (or equivalent) in the stealth-browser
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
                response = await client.post(f"{self.remote_url}/mcp", json=payload)
                response.raise_for_status()
                
                mcp_data = response.json()
                
                # Extract content from the MCP response structure
                # Note: This assumes the stealth-browser returns content in the 'result' field
                content = mcp_data.get("result", {}).get("content", [])

                return ScrapeResult(
                    data=content,
                    metadata=ScrapeMetadata(
                        scraper="stealth_browser_remote",
                        extra={"remote_status": response.status_code}
                    )
                )

            except Exception as e:
                # Log the error with context for observability
                print(f"[ERROR] [StealthPlugin] Failed to connect to remote stealth service at {self.remote_url}: {str(e)}")
                raise e
