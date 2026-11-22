# Changelog
All notable changes to this project will be documented in this file. See [conventional commits](https://www.conventionalcommits.org/) for commit guidelines.

- - -
## [1.0.1](https://github.com/sravioli/mosaic.wz/compare/ad731f221eb0de1605c5c57ee870211b111db60b..1.0.1) - 2026-11-22
#### Bug Fixes
- (**conditions**) compare is_default_workspace with the configured default - ([81313db](https://github.com/sravioli/mosaic.wz/commit/81313db5536d4f44c79fcd7f7c887e583bb8d463)) - sravioli
- (**config**) drop only the invalid options - ([b4af74d](https://github.com/sravioli/mosaic.wz/commit/b4af74d104791feef0f20e68b3cc7a0c36fad372)) - sravioli
- (**cwd**) cache per directory and add an interval option - ([6b2117e](https://github.com/sravioli/mosaic.wz/commit/6b2117e4f70339c20b2167610f04ee406a145365)) - sravioli
- (**powerline**) resolve right-side colors through the palette - ([f55cc4a](https://github.com/sravioli/mosaic.wz/commit/f55cc4a3e3227fe2b6bac52bbe5d90bef00fb9b0)) - sravioli
- (**render**) keep greedy fit within budget, share platform detection - ([71f3b0c](https://github.com/sravioli/mosaic.wz/commit/71f3b0caeb6070f79ebf29ac526294677b5352a4)) - sravioli
#### Documentation
- regenerate the API reference - ([dc42560](https://github.com/sravioli/mosaic.wz/commit/dc4256038384e73b3641b958a77531fa7592608b)) - sravioli
- retake the preset screenshots and load kanagawa from its remote - ([65ff7cd](https://github.com/sravioli/mosaic.wz/commit/65ff7cdeca2b45ce2df755d700c3ec4f1b5b9c5a)) - sravioli
- add minit.lua for reproducing bugs - ([b57b15f](https://github.com/sravioli/mosaic.wz/commit/b57b15fbd989942151afd9817bdf7d61a162c4fb)) - sravioli
#### Tests
- cover is_default_workspace, process icons and invalid options - ([67cd6e9](https://github.com/sravioli/mosaic.wz/commit/67cd6e9402fdd33b87c22089f39b59baf6434d6b)) - sravioli
#### Continuous Integration
- restore the sigil pin and the generated API reference - ([66a5de4](https://github.com/sravioli/mosaic.wz/commit/66a5de4153ec75424ab581e25f303879a8202030)) - sravioli
- pin warp to 1.0.1 - ([761622d](https://github.com/sravioli/mosaic.wz/commit/761622dc1d59213369ef79d562314cf96962377b)) - sravioli
- pin sibling plugins to the current heads - ([24cd011](https://github.com/sravioli/mosaic.wz/commit/24cd0116c0863dccba2a067c9c41711839fd8f70)) - sravioli
- pass the release tag to the shell through env - ([7465cd6](https://github.com/sravioli/mosaic.wz/commit/7465cd6b547c9ae346f2eb91f0244a7c1aa73bf3)) - sravioli
- release from the pushed tag and pin warden with drop_invalid - ([edc7048](https://github.com/sravioli/mosaic.wz/commit/edc704893f034e8ded65b57c00fa6d216399b36f)) - sravioli
- count only the plugin's own files in coverage - ([eb43e0a](https://github.com/sravioli/mosaic.wz/commit/eb43e0a25842e3503d4d63238192c164d08828f8)) - sravioli
- bump cocogitto/cocogitto-action from 3.11 to 4 in the actions group across 1 directory (#2) - ([98db6e1](https://github.com/sravioli/mosaic.wz/commit/98db6e13a954a76aa5e72b98b7fd21aa65f41729)) - [@sravioli](https://github.com/sravioli)
- adapt workflows to cocogitto-action v4 - ([0c14e31](https://github.com/sravioli/mosaic.wz/commit/0c14e31afca143fde4be9f6cdc011fe11d6d79d4)) - sravioli
- bump cocogitto/cocogitto-action - ([ad731f2](https://github.com/sravioli/mosaic.wz/commit/ad731f221eb0de1605c5c57ee870211b111db60b)) - dependabot[bot]
#### Refactoring
- (**cell**) truncate with warp's string helper - ([49b1c31](https://github.com/sravioli/mosaic.wz/commit/49b1c3154efbc2bbf10785a6966228d8778db4ca)) - sravioli
- (**icons**) take process icons from sigil - ([953431e](https://github.com/sravioli/mosaic.wz/commit/953431e8c892e61aa48cb33e88c8a1a6c9c1ab96)) - sravioli
- load log and ribbon from warp - ([842d1bd](https://github.com/sravioli/mosaic.wz/commit/842d1bdfa45d58b5f5de518389db7175b46b8744)) - sravioli
- take every glyph from sigil (#3) - ([fb93b76](https://github.com/sravioli/mosaic.wz/commit/fb93b768b098049d2ec4cf32f9ee18f6f1ad4232)) - [@sravioli](https://github.com/sravioli)
- take every glyph from sigil - ([25695e5](https://github.com/sravioli/mosaic.wz/commit/25695e5d0c94097a3f27da391362e9f90404a2c3)) - sravioli
- sample the system and shorten paths with warp - ([89e4bd6](https://github.com/sravioli/mosaic.wz/commit/89e4bd6d716ee374a21f91a2d5bb1fd2693478a5)) - sravioli

- - -

## [1.0.0](https://github.com/sravioli/mosaic.wz/compare/1ff6e76e6c360c8fc011577e106d101f479143b8..1.0.0) - 2026-11-16
#### Features
- (**api**) add public api and entry point - ([b2e3c01](https://github.com/sravioli/mosaic.wz/commit/b2e3c019eea4109ebb2535e64bd1684fd2ed43c2)) - sravioli
- (**config**) add option schema and integrations - ([acb68a8](https://github.com/sravioli/mosaic.wz/commit/acb68a8dacb50ac83f78235ed8337ae46acbc88e)) - sravioli
- (**doctor**) add diagnostic report - ([300b55b](https://github.com/sravioli/mosaic.wz/commit/300b55b6c745c7a6cbe418d5cbf7a8eec9f68b75)) - sravioli
- (**engine**) add paths, icons and palette - ([5bfa683](https://github.com/sravioli/mosaic.wz/commit/5bfa683d38ab5e13bb86103097e4596c9c059d5f)) - sravioli
- (**engine**) add deps, logger and store - ([cf580a0](https://github.com/sravioli/mosaic.wz/commit/cf580a04e5e0b7af88f3338f2847732b2ed24392)) - sravioli
- (**modules**) add built-in modules - ([7400924](https://github.com/sravioli/mosaic.wz/commit/74009240f69224edc09279ef1adb1851ec0e5018)) - sravioli
- (**presets**) add presets - ([68f4d1f](https://github.com/sravioli/mosaic.wz/commit/68f4d1fc809eef0b8de8b2675d13e0f42bd604d4)) - sravioli
- (**render**) add renderer and fitting - ([c9b0aca](https://github.com/sravioli/mosaic.wz/commit/c9b0aca980e081ddc17a7b28f8948c949d5d3e28)) - sravioli
- (**render**) add budget, conditions and center - ([3432b9f](https://github.com/sravioli/mosaic.wz/commit/3432b9fc0fe4b9c1f66886b12b57742d9132cebe)) - sravioli
- (**status**) add update-status handler - ([2b291bc](https://github.com/sravioli/mosaic.wz/commit/2b291bc6ed98461bb44ca81dbc7289d1697ec739)) - sravioli
- (**system**) add cpu, ram, network samplers - ([0d47b02](https://github.com/sravioli/mosaic.wz/commit/0d47b02574e8d7281e258ccf74e3387f9232ee1c)) - sravioli
- (**tabs**) add tab titles, content and badges - ([c4a07d7](https://github.com/sravioli/mosaic.wz/commit/c4a07d70d0848457540ebf919cf1e6a48ed95b09)) - sravioli
#### Bug Fixes
- (**scripts**) shoot in a nerd font - ([7ba203a](https://github.com/sravioli/mosaic.wz/commit/7ba203a381e92fc54bcc6f6e70e420174bf73824)) - sravioli
- (**scripts**) apply the scheme before the bar - ([2ef18c9](https://github.com/sravioli/mosaic.wz/commit/2ef18c9eb2ffc32ce9a2c15759d16ea1dd6c7c6f)) - sravioli
#### Documentation
- (**api**) name the gradient and tab-defaults table types - ([9dba587](https://github.com/sravioli/mosaic.wz/commit/9dba5878b4739889b09ea43cdfdfcacc39464a53)) - sravioli
- (**api**) regenerate the API reference - ([84a6d23](https://github.com/sravioli/mosaic.wz/commit/84a6d2375cf8574e395ebb487579de5382e5317d)) - sravioli
- (**api**) annotate the public api for apidoc - ([c1b5e42](https://github.com/sravioli/mosaic.wz/commit/c1b5e4296f04c0720c353cc0e0b01abe8f348f89)) - sravioli
- (**contributing**) document the signed-commit requirement - ([967ba64](https://github.com/sravioli/mosaic.wz/commit/967ba64289b801c858f254e4065d66b68ac516a8)) - sravioli
- (**readme**) link the references from a note - ([01ae45c](https://github.com/sravioli/mosaic.wz/commit/01ae45c0faa1749663264411fd5b2fd3f7e4d153)) - sravioli
- (**readme**) show the presets - ([0d32e43](https://github.com/sravioli/mosaic.wz/commit/0d32e43f4b2992823144b855f7b287ca1562d23a)) - sravioli
- adopt the shared community files - ([63dfe3c](https://github.com/sravioli/mosaic.wz/commit/63dfe3c3f8a30afc96e53454c1b3d772732bbad8)) - sravioli
- split the readme into docs/ - ([39e3a77](https://github.com/sravioli/mosaic.wz/commit/39e3a77fc8647c1a8ba4c3867d5bd50392bb1c34)) - sravioli
- add preset screenshots - ([d0da37f](https://github.com/sravioli/mosaic.wz/commit/d0da37f5e42fc8078364ac21c333480bf6c09cbf)) - sravioli
- add contributing guide and templates - ([e97fbeb](https://github.com/sravioli/mosaic.wz/commit/e97fbeb19c7fc23aa167d9c759cb318973a3f5ac)) - sravioli
- add readme and type stubs - ([c5ad9d5](https://github.com/sravioli/mosaic.wz/commit/c5ad9d5edbce211f5ca4066e4aa517a26619b3f9)) - sravioli
#### Tests
- (**bench**) add frame benchmark - ([2103a5e](https://github.com/sravioli/mosaic.wz/commit/2103a5e8a87c75a08db78e32e6313d76a49f8d96)) - sravioli
- add wezterm mock and specs - ([3fa05bd](https://github.com/sravioli/mosaic.wz/commit/3fa05bddd6c993f20117dec1aa9d32099f866c10)) - sravioli
#### Continuous Integration
- build the API reference from a majority of three LuaLS runs - ([926b61f](https://github.com/sravioli/mosaic.wz/commit/926b61feb238e59a17fdbe4ec0b81a1176b3d1b3)) - sravioli
- update the actions to the versions Dependabot proposed - ([017237f](https://github.com/sravioli/mosaic.wz/commit/017237f93e52cbfc2d1a69135339503b25c9737e)) - sravioli
- pin StyLua to 2.6.0 - ([a36aae7](https://github.com/sravioli/mosaic.wz/commit/a36aae77d3ab00eff5b567efb5a07493a512d10a)) - sravioli
- check text, commits and the api docs - ([b4e57f5](https://github.com/sravioli/mosaic.wz/commit/b4e57f530e95381dc8546fd5d0f5c6594106d7c2)) - sravioli
- add lint, test and release workflows - ([47268b5](https://github.com/sravioli/mosaic.wz/commit/47268b54e4295d608f4c79173b40165a153e1ce9)) - sravioli

- - -

Changelog generated by [cocogitto](https://github.com/cocogitto/cocogitto).