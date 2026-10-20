# Third-party notices

## Yams 6.2.2

The YAML parser is vendored, unmodified, in `Vendor/Yams` from the official 6.2.2 source archive:
https://github.com/jpsim/Yams/releases/tag/6.2.2

Yams uses the MIT license. Its full copyright and license text is in `Vendor/Yams/LICENSE` and is included in the application as `Yams-LICENSE.txt`.

### LibYAML

Yams bundles LibYAML. Its MIT copyright and permission notice is preserved separately in `docs/licenses/LibYAML.txt`, from https://github.com/yaml/libyaml/blob/master/License, and included in the application as `LibYAML-LICENSE.txt`.

The official Yams 6.2.2 source archive used for vendoring has SHA-256 `c18b63003173ff886eb781e0cbb2cba612fb5c68485b0cd4e66ad06b686091e8`.

## CCFDDL conference data

Conference metadata is downloaded at runtime from the CCFDDL project, not bundled as a static conference dataset:

- https://ccfddl.com
- https://github.com/ccfddl/ccf-deadlines
- https://github.com/ccfddl/ccf-deadlines/blob/main/LICENSE

The upstream repository identifies its license as MIT. CCFDDL is a community-maintained source; its dates and classifications are attributed to CCFDDL, and the original conference website is retained for checking authoritative information.
