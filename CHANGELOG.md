# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com).

## - 04.07.2026

### Added
- (AFG-01) - Pure CSS lightbox implementation using the `:target` pseudo-class for seamless, non-JS image magnification.
- (AFG-01) - Support for safe unique HTML IDs generated from relative file paths to drive lightbox targeting.
- (AFG-01) - Explicit accessibility and markup validity fixes using non-empty anchor tags with descriptive `aria-label` properties.
- (AFG-01) - Dynamic bilingual folder parsing support for folders named with the `EN_Name (RU_Name)` pattern.
- (AFG-01) - Fluent API style method chaining for .NET string operations inside the PowerShell compiler script.

### Modified
- (AFG-01) - Migrated code style of the compiler script to a strict 2-space indentation with Unix (LF) line endings.
- (AFG-01) - Removed external ThumbsUp/NodeJS dependency, refactoring `gallogen.ps1` into a self-contained, standalone template-based HTML builder.
- (AFG-01) - Extracted HTML layout configurations and styles entirely out of the core logic into `/templates` directory (`index.html`, `album.html`, `photo.html`, `styles.css`).
- (AFG-01) - Forced execution and input/output encoding contexts to UTF-8 to handle Cyrillic characters safely.

### Fixed
- (AFG-01) - Fixed script parsing crashes in WebStorm/PSScriptAnalyzer by replacing problematic bash-style `-trim` switches inside `Where-Object` with native `.NET` `[string]::IsNullOrWhiteSpace()` checks.
- (AFG-01) - Eliminated syntax breaking issues caused by trailing hidden whitespaces after PowerShell line continuation backticks (`` ` ``) by leveraging dot-prefixed Fluent API line breaks.
- (AFG-01) - Replaced fragile directory-checking regular expressions with bulletproof native `[System.IO.Path]::IsPathRooted()` cross-platform validation.
- (AFG-01) - Fixed an array indexing bug inside the `$Matches` regex variable when parsing folder names.

## - 25.05.2023

### Modified
-

### Added
- (AFG-01) - Static gallery structure for GitHub Pages has been generated.

### Fixed
-
