import fs from 'node:fs';
import path from 'node:path';

type PackageJson = {
  version?: string;
};

function getRootPath(relativePath: string): string {
  return path.resolve(__dirname, '..', relativePath);
}

function readPackageVersion(): string {
  const packagePath = getRootPath('package.json');
  const raw = fs.readFileSync(packagePath, 'utf8');
  const parsed = JSON.parse(raw) as PackageJson;

  if (!parsed.version) {
    throw new Error('package.json version is missing');
  }

  return parsed.version;
}

function readChangelogTopEntry(): { version: string; entry: string } {
  const changelogPath = getRootPath('CHANGELOG.md');
  const raw = fs.readFileSync(changelogPath, 'utf8');
  const headerRegex = /^## \[([^\]]+)\] - \d{4}-\d{2}-\d{2}/gm;
  const match = headerRegex.exec(raw);

  if (!match) {
    throw new Error('Top changelog entry not found');
  }

  const startIndex = match.index + match[0].length;
  const nextMatch = headerRegex.exec(raw);
  const endIndex = nextMatch ? nextMatch.index : raw.length;

  return {
    version: match[1],
    entry: raw.slice(startIndex, endIndex),
  };
}

function run(): void {
  const packageVersion = readPackageVersion();
  const { version: changelogVersion, entry: changelogEntry } = readChangelogTopEntry();

  if (packageVersion !== changelogVersion) {
    throw new Error(
      `Version mismatch: package.json=${packageVersion}, CHANGELOG.md=${changelogVersion}`
    );
  }

  if (!/^\s*-\s+\S/m.test(changelogEntry)) {
    throw new Error('Top changelog entry has no bullet items');
  }

  console.log(`✓ Version matches: ${packageVersion}`);
}

try {
  run();
  process.exit(0);
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`✗ ${message}`);
  process.exit(1);
}
