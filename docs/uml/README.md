# UML 说明

## 课程工具标识

`[课程工具标识: UML/PlantUML]` 本目录保存校车管理系统需求和设计阶段的 PlantUML 源文件。UML 图用于支撑 `docs/02_项目需求.md` 和 `docs/03_项目设计.md`，也可导出 PNG/SVG 后放入最终报告或答辩材料。

## UML 文件清单

| 文件 | 图类型 | 用途 | 对应报告章节 |
| --- | --- | --- | --- |
| `use_case_diagram.puml` | 用例图 | 描述普通用户、司机、后台管理员与系统功能的关系 | `docs/02_项目需求.md` 用户需求、用例清单 |
| `passenger_booking_activity.puml` | 活动图 | 描述普通用户预约、支付、取消和信用扣分流程 | `docs/02_项目需求.md` 总体业务流程 |
| `class_diagram.puml` | 类图 | 描述 User、Trip、Booking、Payment、Vehicle、Driver、DispatchPlan、VehicleLocation、Analytics 等核心模型关系 | `docs/03_项目设计.md` 数据设计 |
| `driver_location_sequence.puml` | 顺序图 | 描述司机开始任务、位置上报、到站完成的调用顺序 | `docs/03_项目设计.md` 司机端设计、实时位置设计 |
| `component_diagram.puml` | 组件图 | 描述 Flutter App、Core、Feature、Provider 和 Mock Repository 的组件依赖 | `docs/03_项目设计.md` 系统结构设计 |
| `dispatch_activity.puml` | 调度流程活动图 | 描述后台人工调度和 AI 辅助调度的判断流程 | `docs/03_项目设计.md` AI 调度算法设计 |

## 导出 PNG/SVG

在已安装 PlantUML 和 Java 的环境中，可从项目根目录执行：

```bash
mkdir -p docs/uml/out
plantuml -tpng -o out docs/uml/*.puml
plantuml -tsvg -o out docs/uml/*.puml
```

如果使用 Docker，可执行：

```bash
mkdir -p docs/uml/out
docker run --rm -v "$PWD/docs/uml:/work" plantuml/plantuml -tpng -o out /work/*.puml
docker run --rm -v "$PWD/docs/uml:/work" plantuml/plantuml -tsvg -o out /work/*.puml
```

## 当前图片状态

当前仓库保留 PlantUML 源文件作为 UML 证据，并已通过 Docker/Podman 将 SVG 导出到 `docs/uml/out/`。若最终报告或答辩 PPT 需要 PNG，可按上方命令继续导出 PNG，或直接使用已有 SVG 文件。
