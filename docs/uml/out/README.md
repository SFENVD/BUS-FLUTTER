# UML 导出占位说明

当前执行环境未安装本地 `plantuml` 命令，但已通过 Docker/Podman 执行 `docker.io/plantuml/plantuml` 将 `.puml` 文件导出为 SVG，输出文件位于本目录。若需要 PNG，可在安装 PlantUML 或 Docker 的环境中，按 `docs/uml/README.md` 的命令继续导出。

建议最终提交前补充以下图片：

| PlantUML 源文件 | 建议导出文件 |
| --- | --- |
| `use_case_diagram.puml` | `use_case_diagram.svg` |
| `passenger_booking_activity.puml` | `passenger_booking_activity.svg` |
| `class_diagram.puml` | `class_diagram.svg` |
| `driver_location_sequence.puml` | `driver_location_sequence.svg` |
| `component_diagram.puml` | `component_diagram.svg` |
| `dispatch_activity.puml` | `dispatch_activity.svg` |
