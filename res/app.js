
const OWNER = "alx0rr";
const REPO = "AltTeam-App";

const API = `https://api.github.com/repos/${OWNER}/${REPO}`;

const $ = id => document.getElementById(id);

function formatDate(date) {
    return new Date(date).toLocaleDateString(undefined, {
        year: "numeric",
        month: "long",
        day: "numeric"
    });
}

function formatSize(bytes) {
    return (bytes / 1024 / 1024).toFixed(1) + " MB";
}

function createFile(asset) {
    const row = document.createElement("div");
    row.className = "file";

    const info = document.createElement("div");
    info.className = "file-info";

    const name = document.createElement("div");
    name.className = "file-name";
    name.textContent = asset.name;

    const meta = document.createElement("div");
    meta.className = "file-meta";

    const parts = [formatSize(asset.size)];

    if (asset.digest?.startsWith("sha256:")) {
        parts.push("SHA256: " + asset.digest.slice(7));
    }

    meta.textContent = parts.join(" · ");

    info.append(name, meta);

    const link = document.createElement("a");
    link.className = "download";
    link.href = asset.browser_download_url;
    link.textContent = "Download";
    link.setAttribute("download", "");

    row.append(info, link);

    return row;
}

function createSourceFile(name, url) {
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
    link.href = url;
    link.textContent = "Download";

    row.append(info, link);

    return row;
}

function createAssetGroups(assets) {
    const container = document.createElement("div");

    const groups = [
        {
            title: "Android",
            files: assets.filter(a =>
                a.name.toLowerCase().endsWith(".apk")
            )
        },
        {
            title: "iOS",
            files: assets.filter(a =>
                a.name.toLowerCase().endsWith(".ipa")
            )
        },
        {
            title: "Other",
            files: assets.filter(a =>
                !/\.(apk|ipa)$/i.test(a.name)
            )
        }
    ];

    for (const group of groups) {
        if (!group.files.length) continue;

        const heading = document.createElement("h3");
        heading.textContent = group.title;

        const list = document.createElement("div");
        list.className = "file-list";

        for (const asset of group.files) {
            list.append(createFile(asset));
        }

        container.append(heading, list);
    }

    if (!assets.length) {
        const empty = document.createElement("p");
        empty.className = "file-meta";
        empty.textContent = "No downloadable files available.";
        container.append(empty);
    }

    return container;
}

function createSourceFiles(release) {
    const container = document.createElement("div");

    const heading = document.createElement("h3");
    heading.textContent = "Source code";

    const list = document.createElement("div");
    list.className = "file-list";

    const zipUrl = release.zipball_url;
    const tarUrl = release.tarball_url;

    list.append(
        createSourceFile("Source code (ZIP)", zipUrl),
        createSourceFile("Source code (TAR.GZ)", tarUrl)
    );

    container.append(heading, list);

    return container;
}

function renderReleaseFiles(container, release) {
    container.replaceChildren(
        createAssetGroups(release.assets || []),
        createSourceFiles(release)
    );
}

function renderLatest(release) {
    $("version").textContent =
        release.name || release.tag_name;

    $("release-date").textContent =
        "Released " + formatDate(release.published_at);

    $("release-notes").textContent =
        release.body || "No release notes available.";

    $("latest-github").href = release.html_url;

    renderReleaseFiles($("latest-files"), release);
}

function createReleaseCard(release) {
    const details = document.createElement("details");
    details.className = "release-item";

    const summary = document.createElement("summary");
    summary.className = "release-summary";

    const left = document.createElement("div");
    left.className = "release-summary-left";

    const name = document.createElement("div");
    name.className = "release-name";
    name.textContent = release.name || release.tag_name;

    const info = document.createElement("div");
    info.className = "release-info";

    const date = release.published_at
        ? formatDate(release.published_at)
        : "Unpublished";

    const files = release.assets?.length || 0;

    info.textContent = `${date} · ${files} assets`;

    left.append(name, info);

    const right = document.createElement("div");
    right.className = "release-summary-right";

    if (release.prerelease) {
        const badge = document.createElement("span");
        badge.className = "release-tag";
        badge.textContent = "PRE-RELEASE";
        right.append(badge);
    }

    const tag = document.createElement("span");
    tag.className = "release-tag";
    tag.textContent = release.tag_name;

    const arrow = document.createElement("span");
    arrow.className = "release-arrow";
    arrow.textContent = "⌄";

    right.append(tag, arrow);

    summary.append(left, right);

    const content = document.createElement("div");
    content.className = "release-content";

    const description = document.createElement("div");
    description.className = "release-description";
    description.textContent =
        release.body || "No release notes available.";

    content.append(
        description,
        createAssetGroups(release.assets || []),
        createSourceFiles(release)
    );

    const github = document.createElement("a");
    github.className = "release-github";
    github.href = release.html_url;
    github.target = "_blank";
    github.rel = "noopener noreferrer";
    github.textContent = "View release on GitHub ↗";

    content.append(github);

    details.append(summary, content);

    return details;
}

async function fetchAllReleases() {
    const releases = [];
    const perPage = 100;

    for (let page = 1; ; page++) {
        const response = await fetch(
            `${API}/releases?per_page=${perPage}&page=${page}`
        );

        if (!response.ok) {
            throw new Error("GitHub API error: " + response.status);
        }

        const batch = await response.json();

        releases.push(...batch);

        if (batch.length < perPage) break;
    }

    return releases;
}

function renderHistory(releases, latest) {
    const container = $("releases-list");
    container.replaceChildren();

    // Avoid showing the latest stable release twice.
    const history = releases.filter(
        release => release.id !== latest.id
    );

    $("release-count").textContent =
        `${releases.length} releases`;

    if (!history.length) {
        const empty = document.createElement("div");
        empty.className = "loading";
        empty.textContent = "No previous releases available.";
        container.append(empty);
        return;
    }

    for (const release of history) {
        container.append(createReleaseCard(release));
    }
}

async function init() {
    try {
        const [latestResponse, releases] = await Promise.all([
            fetch(`${API}/releases/latest`),
            fetchAllReleases()
        ]);

        if (!latestResponse.ok) {
            throw new Error("Latest release unavailable.");
        }

        const latest = await latestResponse.json();

        renderLatest(latest);
        renderHistory(releases, latest);

    } catch (error) {
        console.error("Failed to load releases:", error);

        $("version").textContent = "Unavailable";

        $("release-notes").textContent =
            "Unable to load release information. Please try again later.";

        $("releases-list").replaceChildren();

        $("load-error").classList.remove("hidden");
    }
}

init();
