
const OWNER = "alx0rr";
const REPO = "AltTeam-App";

const API = `https://api.github.com/repos/${OWNER}/${REPO}/releases/latest`;

const $ = (id) => document.getElementById(id);

function createFile(asset) {
    const hash = asset.digest
        ? asset.digest.replace("sha256:", "")
        : null;

    const row = document.createElement("div");
    row.className = "file";

    const info = document.createElement("div");
    info.className = "file-info";

    const name = document.createElement("div");
    name.className = "file-name";
    name.textContent = asset.name;

    const meta = document.createElement("div");
    meta.className = "file-meta";
    meta.textContent = [
        (asset.size / 1024 / 1024).toFixed(1) + " MB",
        hash ? "SHA256: " + hash : null
    ].filter(Boolean).join(" · ");

    info.append(name, meta);

    const link = document.createElement("a");
    link.className = "download";
    link.href = asset.browser_download_url;
    link.textContent = "Download";
    link.setAttribute("download", "");

    row.append(info, link);

    return row;
}

function renderFiles(assets) {
    const android = assets.filter(a =>
        a.name.toLowerCase().endsWith(".apk")
    );

    const ios = assets.filter(a =>
        a.name.toLowerCase().endsWith(".ipa")
    );

    const androidContainer = $("android-files");
    const iosContainer = $("ios-files");

    androidContainer.replaceChildren();
    iosContainer.replaceChildren();

    for (const asset of android) {
        androidContainer.append(createFile(asset));
    }

    for (const asset of ios) {
        iosContainer.append(createFile(asset));
    }

    if (!android.length) {
        androidContainer.textContent = "No Android builds available.";
    }

    if (!ios.length) {
        iosContainer.textContent = "No iOS builds available.";
    }

    const source = $("source-files");
    source.replaceChildren();

    const zip = assets.find(a => a.name === "Source code (zip)");
    const tar = assets.find(a => a.name === "Source code (tar.gz)");

    // GitHub automatically generates source archives.
    const tag = document.body.dataset.tag;

    for (const [name, extension] of [
        ["Source code (ZIP)", "zip"],
        ["Source code (TAR.GZ)", "tar.gz"]
    ]) {
        const row = document.createElement("div");
        row.className = "file";

        const info = document.createElement("div");
        info.className = "file-info";

        const title = document.createElement("div");
        title.className = "file-name";
        title.textContent = name;

        const meta = document.createElement("div");
        meta.className = "file-meta";
        meta.textContent = "GitHub source archive";

        info.append(title, meta);

        const link = document.createElement("a");
        link.className = "download";
        link.href = `https://github.com/${OWNER}/${REPO}/archive/refs/tags/${encodeURIComponent(tag)}.${extension}`;
        link.textContent = "Download";

        row.append(info, link);
        source.append(row);
    }
}

async function loadRelease() {
    try {
        const response = await fetch(API);

        if (!response.ok) {
            throw new Error("GitHub API error: " + response.status);
        }

        const release = await response.json();

        $("version").textContent = release.name || release.tag_name;

        $("release-date").textContent =
            "Released " + new Date(release.published_at)
                .toLocaleDateString(undefined, {
                    year: "numeric",
                    month: "long",
                    day: "numeric"
                });

        $("release-notes").textContent =
            release.body || "No release notes available.";

        document.body.dataset.tag = release.tag_name;

        renderFiles(release.assets || []);

    } catch (error) {
        console.error(error);
        $("version").textContent = "Unavailable";
        $("release-notes").textContent =
            "Unable to load release information. Please try again later.";
    }
}

loadRelease();
