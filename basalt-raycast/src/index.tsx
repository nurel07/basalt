import {
  Detail,
  ActionPanel,
  Action,
  showToast,
  Toast,
  Icon,
  open,
} from "@raycast/api";
import { useFetch } from "@raycast/utils";
import {
  setDesktopWallpaper,
  downloadWallpaper,
  getThumbnailUrl,
  Wallpaper,
  API_URL,
} from "./utils";

export default function Command() {
  const { isLoading, data: wallpaper } = useFetch<Wallpaper>(API_URL, {
    onError: (error) => {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to load wallpaper",
        message: error.message,
      });
    },
  });

  const markdown = wallpaper
    ? `![${wallpaper.name}](${getThumbnailUrl(wallpaper.url, 500)})`
    : "";

  return (
    <Detail
      isLoading={isLoading}
      navigationTitle="Today's Wallpaper"
      markdown={markdown}
      metadata={
        wallpaper ? (
          <Detail.Metadata>
            <Detail.Metadata.Label title="Title" text={wallpaper.name} />
            <Detail.Metadata.Label title="Artist" text={wallpaper.artist} />
            <Detail.Metadata.Label title="Year" text={wallpaper.creationDate} />
            <Detail.Metadata.Separator />
            <Detail.Metadata.Link
              title=""
              target="https://basalt.yevgenglukhov.com/today"
              text="Learn more about the artwork"
            />
          </Detail.Metadata>
        ) : null
      }
      actions={
        wallpaper ? (
          <ActionPanel>
            <Action
              title="Set Desktop Wallpaper"
              icon={Icon.Desktop}
              onAction={async () => {
                const toast = await showToast({
                  style: Toast.Style.Animated,
                  title: "Setting wallpaper...",
                });
                try {
                  await setDesktopWallpaper(wallpaper.url);
                  toast.style = Toast.Style.Success;
                  toast.title = "Wallpaper set successfully";
                } catch (error) {
                  toast.style = Toast.Style.Failure;
                  toast.title = "Failed to set wallpaper";
                  toast.message =
                    error instanceof Error ? error.message : String(error);
                }
              }}
            />
            <ActionPanel.Section>
              <Action
                title="Download Wallpaper"
                icon={Icon.Download}
                shortcut={{ modifiers: ["cmd"], key: "d" }}
                onAction={async () => {
                  const toast = await showToast({
                    style: Toast.Style.Animated,
                    title: "Downloading...",
                  });
                  try {
                    const path = await downloadWallpaper(
                      wallpaper.url,
                      wallpaper.name,
                    );
                    toast.style = Toast.Style.Success;
                    toast.title = "Wallpaper downloaded";
                    toast.message = `Saved to ${path}`;
                  } catch (error) {
                    toast.style = Toast.Style.Failure;
                    toast.title = "Download failed";
                    toast.message =
                      error instanceof Error ? error.message : String(error);
                  }
                }}
              />
              <Action
                title="Install Basalt App"
                icon={Icon.Monitor}
                onAction={() => open("https://basalt.yevgenglukhov.com")}
              />
            </ActionPanel.Section>
          </ActionPanel>
        ) : null
      }
    />
  );
}
