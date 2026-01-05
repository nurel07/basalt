import { NextResponse } from 'next/server';

export const revalidate = 300; // Cache for 5 minutes

const GITHUB_USER = 'nurel07';
const GITHUB_REPO = 'Basalt';

interface GitHubRelease {
    tag_name: string;
    html_url: string;
    published_at: string;
    body: string;
    assets: {
        browser_download_url: string;
        name: string;
        content_type: string;
        size: number;
    }[];
}

export async function GET() {
    try {
        const response = await fetch(
            `https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}/releases/latest`,
            {
                headers: {
                    'Accept': 'application/vnd.github.v3+json',
                    'User-Agent': 'Basalt-Appcast-Generator'
                },
                next: { revalidate: 300 }
            }
        );

        if (!response.ok) {
            console.error('GitHub API Error:', response.status, response.statusText);
            return new NextResponse('Error fetching releases', { status: 500 });
        }

        const release: GitHubRelease = await response.json();

        // Find the DMG asset (prioritize .dmg, fallback to .zip)
        const asset = release.assets.find(a => a.name.endsWith('.dmg'))
            || release.assets.find(a => a.name.endsWith('.zip'));

        if (!asset) {
            return new NextResponse('No suitable asset found in latest release', { status: 404 });
        }

        // Attempt to extract Sparkle Signature from release notes
        // Look for pattern: <!-- sparkle:edSignature=... -->
        const signatureMatch = release.body.match(/<!-- sparkle:edSignature=([a-zA-Z0-9+/=]+) -->/);
        const signature = signatureMatch ? signatureMatch[1] : '';

        // If no signature found in body, check for a separate .sig asset
        // (Optimization: This would require another fetch, skipping for now unless critical)

        const version = release.tag_name.replace(/^v/, ''); // Remove 'v' prefix if present

        const xml = `<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <title>Basalt Updates</title>
    <item>
      <title>${release.tag_name}</title>
      <pubDate>${new Date(release.published_at).toUTCString()}</pubDate>
      <description><![CDATA[
        ${release.body}
      ]]></description>
      <enclosure 
        url="${asset.browser_download_url}"
        sparkle:version="${version}"
        sparkle:shortVersionString="${version}"
        length="${asset.size}"
        type="application/octet-stream"
        ${signature ? `sparkle:edSignature="${signature}"` : ''}
      />
    </item>
  </channel>
</rss>`;

        return new NextResponse(xml, {
            headers: {
                'Content-Type': 'application/xml',
                'Cache-Control': 's-maxage=300, stale-while-revalidate',
            },
        });

    } catch (error) {
        console.error('Appcast Generation Error:', error);
        return new NextResponse('Internal Server Error', { status: 500 });
    }
}
