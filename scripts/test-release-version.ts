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

function readChangelogTopVersion(): string {
  const changelogPath = getRootPath('CHANGELOG.md');
  const raw = fs.readFileSync(changelogPath, 'utf8');
  const match = raw.match(/^## \[([^\]]+)\] - \d{4}-\d{2}-\d{2}/m);

  if (!match) {
    throw new Error('Top changelog entry not found');
  }

  return match[1];
}

function run(): void {
  const packageVersion = readPackageVersion();
  const changelogVersion = readChangelogTopVersion();

  if (packageVersion !== changelogVersion) {
    throw new Error(
      `Version mismatch: package.json=${packageVersion}, CHANGELOG.md=${changelogVersion}`
    );
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
