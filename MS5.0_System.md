MS5.0 — Software Build Bible

A complete technical specification for MS5.0 Core, Floor & People

Audience: software engineers, data/ML engineers, SRE/DevOps, security engineers, solution architects, and product owners.
Scope: this document defines the target architecture, service boundaries, data contracts, security model, DevOps practices, and detailed build plans for MS5.0. It is prescriptive: where trade‑offs exist, we choose a default and explain why.

⸻

0) Why MS5.0 is designed this way (grounding & references)

MS5.0 is intentionally built to digitize the management system through the work, not around it. The software embodies Integrated Work Systems (IWS), Leader Standard Work (LSW), TPM, Lean, Six Sigma and Continuous Improvement so that by using the tools, users are implementing the system and the system audits itself.
	•	Leader Standard Work (LSW): daily/weekly/monthly routines, gemba walks, KPI review, coaching loops. MS5.0 People and Floor include LSW planners, guided gemba routes, and coaching audits that mirror best practice (see the LSW primer on routines, gemba and sustainment; also note the digitization benefits for connected workers).  ￼
	•	IWS & Connected Worker: MS5.0 Floor operationalizes Daily Direction Setting (DDS), DMS, Centerlines, CIL (Clean‑Inspect‑Lubricate), Defect/Breakdown elimination, Changeover, Skill matrices and visual management, aligned with IWS core components and benefits (e.g., Andon, 5S, skills/competency tracking).  ￼
	•	Run‑to‑Target (RTT) & Loss Elimination: Our DDS, Loss Map, and Unplanned Stop focus follow the cadence demonstrated in P&G’s IWS leadership deck (e.g., focus on unplanned stops impacts all KPIs; standard DDS meetings and loss maps; eManufacturing foundation). (See slides on RTT focus, standardized DDS meetings and loss maps.)  ￼
	•	Lean Six Sigma: MS5.0 embeds DMAIC workflows, variation reduction analytics, and waste classification (8 wastes) in the analytics layer and problem‑solving templates.  ￼
	•	Continuous Improvement: PDCA is our default engine for experiments; we support suggestion → kaizen → standardization loops and cross‑industry CI practices, with AI assistance for insight discovery.  ￼
	•	Digital Done Right: We ship an Optimize‑Before‑Digitize Gate—a built‑in assessment and stabilization toolkit—so we never automate waste or entrench bad processes. (Rationale and case studies of failed digitizations support this approach.)  ￼
	•	SOPs that work in the real world: A native SOP/Standard Work engine with versioning, roles, and visual/OPL formats; authored for clarity, kept current, and accessible offline, echoing practical guidance for SOP adoption.  ￼
	•	IWS Pillars & Culture: We map software modules to the IWS 12 pillars and five guiding principles (DMS, DDS, Learn‑Do‑Teach, Tools Supporting Zero Loss, Servant Leadership).  ￼
	•	TPM: We digitize the 8 TPM pillars, emphasize AM (autonomous maintenance), planned maintenance, quality maintenance, Early Equipment Management, and one‑point lessons—feeding OEE analytics by design.  ￼

⸻

1) Product Outline

1.1 Names & responsibilities
	•	MS5.0 Core: the platform—identity, authorization, data platform, API routing, event streaming, workflow/agents, audit, integrations, and developer console.
	•	MS5.0 Floor: the factory work app—production, quality, HSE, maintenance (TPM), improvement, DDS/DMS, centerlines, CIL, Andon, loss mapping, changeovers, shift handover, visual management.
	•	MS5.0 People: people ops—skills & competency matrices, training & OPLs, LSW planners, 1‑1s/appraisals, leave/absence, and workforce scheduling.

1.2 Non‑functional requirements (NFRs)
	•	Reliability: Platform SLO 99.9% monthly for core APIs; critical Floor offline mode ≤ 12h store‑and‑forward.
	•	Security: OIDC SSO, mTLS service mesh, fine‑grained ABAC, end‑to‑end encryption, append‑only audit.
	•	Latency targets: P95 UI action→API < 250ms local; streaming telemetry end‑to‑insight < 5s.
	•	Data durability: RPO ≤ 5 minutes (Kafka ISR), RTO ≤ 30 minutes regional failover.
	•	Compliance‑ready: support ISO 9001/27001; electronic records/e‑sign (Part 11–style) where required; role‑segregation and immutable audits.

⸻

2) Reference Architecture

2.1 Logical view (top level)

[Clients]
  Floor PWA (offline)  |  People Web  |  Core Admin Console
        |                      |                   |
        v                      v                   v
                [API Gateway + GraphQL BFF]
                           |
             +-------------+--------------+
             |                            |
        [MS5.0 Core]                 [Data Platform]
  Auth/Directory | Workflow/Agents | Event Streaming | Object Store
  Policy (ABAC)  | API Router      | Time-series     | Data Lake
  Audit & E-sign | Integrations    | Search          | Analytics

2.2 Technology choices (opinionated defaults)
	•	Runtime & Orchestration: Kubernetes (≥1.29), containerized microservices; Horizontal Pod Autoscaling; cluster‑per‑tenant (large tenants) or namespace‑per‑tenant (SMB).
	•	Languages:
	•	Services: TypeScript (Node.js 20 LTS) for developer velocity & Temporal SDK; Go for high‑throughput adapters (OPC UA/MQTT).
	•	ML/Analytics jobs: Python 3.11.
	•	APIs: REST+JSON for external; internal gRPC; GraphQL BFF for UI.
	•	Workflow Orchestration: Temporal (TypeScript/Go) for long‑running, auditable workflows (DDS, SOP runs, changeovers, AM steps).
	•	Event streaming: Apache Kafka (KRaft) with schema registry (Avro/JSON Schema); Debezium CDC.
	•	Datastores:
	•	OLTP: PostgreSQL 15 (row‑level security), TimescaleDB for time‑series.
	•	Search: OpenSearch (full‑text + aggregations).
	•	Cache: Redis.
	•	Files/media: S3‑compatible object storage (MinIO or cloud S3).
	•	Analytics lake: Parquet on object storage with Apache Iceberg table format; Spark or Flink jobs.
	•	Observability: OpenTelemetry → Prometheus (metrics), Tempo/Jaeger (traces), Loki (logs), Grafana dashboards.
	•	Identity & Policy: Keycloak (OIDC), OPA/Rego for ABAC; just‑in‑time user provisioning via SCIM.
	•	Secrets: KMS‑backed sealed secrets (e.g., AWS KMS or HashiCorp Vault).

Rationale: The platform is event‑first and workflow‑centric because production & people processes are long‑lived, auditable and involve humans + machines. This supports DDS/DMS/RTT patterns and connected worker loops shown in IWS materials, with automated data capture to reduce effort and create data‑driven insights.  ￼  ￼

2.3 Deployment view
	•	Core plane: multi‑region Kubernetes with Kafka cluster, Postgres HA, MinIO or S3, OpenSearch, Temporal cluster, Keycloak, OPA, Prometheus/Loki/Tempo/Grafana.
	•	Edge plane: MS5.0 Edge Gateway—an industrial PC container stack with:
	•	edge-opcua-adapter (Go): OPC UA client, tag mapping, security (X.509), publishes compressed protobuf messages to Kafka over TLS.
	•	edge-mqtt-bridge: MQTT v3.1.1/v5 ingestion from sensors/PLCs; local disk queue (bad networks).
	•	edge-storeforward: RocksDB queue; retries with exponential backoff.
	•	edge-ml-probes: optional anomaly scoring at edge (ONNX runtime), so DDS boards show early warnings even if WAN is down.
	•	Client plane:
	•	Floor PWA (React + Workbox offline): rugged tablets, shared workstations, HMIs.
	•	People Web (React): desktop/tablet; HR & leaders.
	•	Core Admin (React): developers & admins.

⸻

3) Domain map → Microservices

We use Domain‑Driven Design (DDD). Services expose REST/gRPC and publish/consume events. The canonical event model ensures consistent analytics.

3.1 Core (platform) services
	•	core-authz: OIDC, ABAC policies; tenant & org structures; attribute issuers.
	•	core-audit: append‑only, hash‑chained audit ledger (WORM); e‑sign flows.
	•	core-workflow: Temporal server & workers; workflow templates library (DDS, CIL, AM steps, changeover, FMEA/DMAIC).
	•	core-events: Kafka topics, schema registry, event enrichment (site, line, equipment metadata).
	•	core-data: Data contracts, CDC to lake, lineage (Marquez/OpenLineage).
	•	core-search: OpenSearch indexer; unified search API.
	•	core-integration: ERP/MES/CMMS connectors; iPaaS adapters; webhooks & iCal.
	•	core-ml: feature store, model registry, scheduled jobs (predictive maintenance, FPY drift, skills gap recommender).
	•	core-admin: web console for devs: routing rules, schemas, connectors, feature flags.

3.2 Floor services (operations)
	•	floor-dms: Daily Management System; boards, KPIs, actions, escalations.
	•	floor-dds: Daily Direction Setting; ritual timer, agenda, last/next 24h risks; Run‑to‑Target status; standardized agendas & checklists (like slide 40’s DDS standard).  ￼
	•	floor-andon: Andon calls, escalation paths (call tree), takt alarms, and visual signals consistent with IWS visual management.  ￼
	•	floor-centerlines: centerline definitions, spec bands, restore‑to‑standard workflow; edge alerts when drift; “Quality to Start” pre‑run validation (modeled as Temporal workflow). (See RTT work processes that include Centerlines and “quality to start”.)  ￼
	•	floor-cil: Clean‑Inspect‑Lubricate planner; auto‑generate AM routines; offline checklists; photo evidence & defect logging (TPM alignment).  ￼
	•	floor-defects: defect capture, triage, Unified Problem Solving templates (5‑Whys, Ishikawa, FMEA), DMAIC scaffolds.  ￼
	•	floor-breakdown-elimination: incident correlation, counter‑measure deployment tracking; change effectiveness reviews.
	•	floor-changeover: SMED tasks orchestration, preflight/line clearance, post‑run verification; time capture for CO loss.
	•	floor-lossmap: spatial loss mapping on area/line diagrams (inspired by the loss map visuals; teams identify & prioritize losses).  ￼
	•	floor-oee: OEE service (Availability × Performance × Quality) with event‑sourced run/stop, rates, scrap, rework.
	•	floor-quality: in‑process checks, FPY, SPC, sampling plans; digital NCRs; CAPA.
	•	floor-hse: audits, near‑miss, JSA, LOTO governance; layered process audits.
	•	floor-shifthandover: logbooks, shift KPIs, open actions, standing issues.
	•	floor-visuals: board runtime for DMS/DDS, Andon, centerline dashboards, skills wall.

RTT Alignment: The service suite embodies line‑centric RTT: focus on unplanned stops (service floor-dds & floor-oee KPIs); run the few things that matter; standardized DDS and visual boards; team capability building. (See slides on typical vs RTT vs high‑performing states and unplanned stop focus.)  ￼

3.3 People services (workforce)
	•	people-identitylink: syncs org roles, areas, lines, cells (operators → equipment ownership).
	•	people-skills: skills & competency matrices; proficiency bands; auto‑assignment of work to capability; Learn‑Do‑Teach pathways. (Connected worker skills tracking exemplified.)  ￼
	•	people-training: curricula, micro‑learning, One‑Point Lessons (OPL), certification & recert windows (ties to SOP changes).  ￼
	•	people-lsw: Leader Standard Work schedules, gemba routes, question sets, coaching notes, and sustainment reviews (aligns to LSW steps from identification → standardization → training → monitor & sustain; includes digitized gemba).  ￼
	•	people-appraisals: goals, 1‑1s, feedback, evidence from Floor (wins + defects solved).
	•	people-leave: leave/absence, shift assignments, skill‑aware rostering.

3.4 SOP/Standard Work services
	•	stdwork-author: SOP authoring (rich media, steps, roles, PPE, hazards), versioning, review/approve with e‑sign.
	•	stdwork-runtime: assignment engine, offline execution, step timers, verification, Visual/Photo steps and OPLs; link to DMS/DDS. (Matches best practice SOP clarity & accessibility.)  ￼

⸻

4) Data & Event Contracts

4.1 Canonical entities (selected)
	•	Site / Area / Line / Equipment
	•	Shift / Team / User (with skills, certifications)
	•	Run / Stop (planned/unplanned), Loss, Defect, Changeover, CIL Task, Centerline, Quality Check, Audit Finding, Incident, Action
	•	SOP / SOPVersion / OPL, TrainingRecord, LSWSchedule/Visit

4.2 Example event schemas (JSON, v1)

Unplanned stop (production.stop.unplanned.v1)

{
  "event_id": "uuid",
  "occurred_at": "2025-09-20T14:52:05Z",
  "site_id": "S-BHAM",
  "line_id": "L-SF100",
  "equipment_id": "EQ-FILLER-1",
  "shift_id": "2025-09-20-A",
  "duration_ms": 420000,
  "code": "STARVATION_CAP_FEED",
  "classification": "mechanical",
  "detected_by": "edge-opcua",
  "ack_user_id": "u-ops-44",
  "root_cause_id": null,
  "attachments": []
}

Centerline change (process.centerline.changed.v1)

{
  "event_id": "uuid",
  "occurred_at": "2025-09-20T15:10:00Z",
  "line_id": "L-SF100",
  "equipment_id": "EQ-FILLER-1",
  "parameter": "seamer_torque",
  "from": 28.0,
  "to": 32.0,
  "spec_low": 30.0,
  "spec_high": 34.0,
  "reason": "material viscosity shift",
  "approved_by": "u-linelead-2",
  "work_instruction_id": "wi-123"
}

CIL completion (maintenance.cil.completed.v1)

{
  "event_id": "uuid",
  "task_id": "cil-7781",
  "equipment_id": "EQ-CAPPER-2",
  "performed_by": "u-op-17",
  "started_at": "2025-09-20T06:05:00Z",
  "completed_at": "2025-09-20T06:17:30Z",
  "findings": [{"type": "leak", "severity": "medium", "photo": "s3://..."}],
  "defect_ids": ["def-9011"],
  "signature": {"user_id": "u-op-17", "method": "e-sign", "hash": "sha256:..."}
}

Why these events: They unlock OEE, DDS focus on unplanned stops, centerline discipline, and TPM AM—exactly the levers called out in IWS/TPM.  ￼  ￼  ￼

4.3 Storage patterns
	•	OLTP (Postgres): normalized core entities; RLS per tenant; JSONB for flexible attributes.
	•	Time‑series (Timescale): high‑write equipment signals; hypertables; continuous aggregates for minute/hour KPIs.
	•	Search (OpenSearch): denormalized indices for tasks, SOPs, incidents (fast discovery).
	•	Lake (Parquet/Iceberg): gold tables per domain for analytics, DMAIC, and CI dashboards.

⸻

5) API Surface (selected)

All endpoints versioned (/v1), JWT/OIDC protected. GraphQL BFF composes underlying services.

5.1 Floor/DDS
	•	POST /v1/dds/sessions — create DDS for a line/shift (template_id, timebox, agenda).
	•	GET /v1/dds/sessions/{id} — retrieve; includes KPIs (OEE, unplanned stops last 24h), risks next 24h, actions.
	•	POST /v1/dds/sessions/{id}/actions — add actions with owner/ETA/escalation.

5.2 Centerlines
	•	GET /v1/centerlines/{equipment_id} — current spec and history.
	•	POST /v1/centerlines/changes — propose/apply change; workflow approval; emits process.centerline.changed.v1.

5.3 CIL / AM
	•	POST /v1/cil/plans:generate — derive AM tasks from equipment profile & TPM step; cadence rules.
	•	PATCH /v1/cil/tasks/{id} — progress, photos, findings; offline‑safe patch (CRDT merge).

5.4 SOP runtime
	•	GET /v1/sop/{sop_id}/latest — download runtime bundle (steps, media, hazards, PPE).
	•	POST /v1/sop/runs — start run; step telemetry; e‑sign on completion.

5.5 People/Skills
	•	GET /v1/skills/matrix?area=... — skill grid; proficiency, recert dates.
	•	POST /v1/opls — publish one‑point lesson; link to defects/AM.

⸻

6) Workflows (Temporal specs)

Workflows are code and data—versioned, replayable, and fully audited.

6.1 DDS Session Workflow
	1.	Initialize agenda (safety → quality → throughput → service → staffing/conditions) based on last 24h/next 24h. (Mirrors standardized DDS meeting flow.)  ￼
	2.	Fetch KPIs (OEE, unplanned stop count, defects found/fixed).
	3.	Generate action queue; assign owners; set escalation triggers.
	4.	Record decisions & e‑sign; publish dds.session.completed.v1.

6.2 AM Step‑Up (Autonomous Maintenance)
	•	Eight‑step progression to AM base condition (safety map → clean → find/fix defects → eliminate contamination → understand function → define CIL/CL → track results → improve standards), with specific content blocks and audits. (These steps reflect TPM best practice and operator development.)  ￼

6.3 Changeover (SMED)
	•	Pre‑run checklist → idle → change tooling → verify → “quality to start” → first‑off OK; captures CO time buckets.

6.4 DMAIC Improvement
	•	Define (problem, VOC, CTQs) → Measure (baseline) → Analyze (hypothesis tests) → Improve (experiments) → Control (SPC); includes templates, guardrails, and approvals.  ￼

⸻

7) Frontend Architecture

7.1 Floor PWA (offline‑first)
	•	Stack: React, TypeScript, Redux Toolkit Query, Workbox, IndexedDB (Dexie).
	•	Offline patterns:
	•	Append‑only local event log → background sync to /bulk/events.
	•	CRDT/OT merge for checklist and notes fields.
	•	Conflict resolution UI if server rejects.
	•	Rugged UX: big tap targets, dark mode, barcode/QR scan (WebRTC), camera/photo markup, glove‑friendly.
	•	Visual management: DDS/DMS boards, Andon tiles, centerline gauges; support for Andon and 5S visual cues as per IWS.  ￼

7.2 People & Core Admin
	•	People: skills wall, LSW planner (calendar + routes), coaching forms, 1‑1 workflows. (Digitized LSW routines & gemba with structured prompts.)  ￼
	•	Admin: schema registry UI, topic explorer, SOP governance, policy editor (Rego), integration hub.

⸻

8) Security & Privacy
	•	Identity: OIDC SSO (Keycloak), MFA optional per tenant policy.
	•	AuthZ: ABAC via OPA—policies express who can do what where (e.g., “operators may edit CIL on their owned equipment within shift”).
	•	Network: mTLS between services; mutual trust anchors.
	•	Data:
	•	Encryption in transit (TLS 1.3) and at rest (disk/KMS).
	•	Audit ledger: hash‑chained (audit_id, prev_hash, record_hash) to detect tamper.
	•	Data segregation by tenant_id and site_id (RLS).
	•	E‑sign: dual authentication steps with intent/meaning confirmation; 21 CFR Part 11–style traceability where required.

⸻

9) Analytics & AI

9.1 Metrics & KPIs (gold tables)
	•	oee_by_line_day, unplanned_stops_by_equipment, centerline_drift_scores, cil_completion_adherence, fpy_by_sku_shift, loss_map_clusters.

9.2 Models & Agents
	•	Predictive maintenance: anomaly detection on timeseries (IsolationForest/ESD); forecast stoppages; notify DDS (“risk in next 24h”).
	•	Quality drift: FPY/CTQ drift detection; suggest centerline tweaks.
	•	Skills gap & scheduling: recommend assignments to meet DDS plan given skills matrix and recert windows. (Skills tracking/value shown in connected worker/IWS material.)  ￼
	•	Agent Orchestrator: tool‑use policies; functions: fetch SOP, file defect, schedule AM, start DDS; guardrails and reasoning traces recorded—leaders can coach “Learn‑Do‑Teach”.

⸻

10) Integrations
	•	ERP (SAP/Oracle): materials master, BOM, work orders, confirmations.
	•	MES/SCADA: run declarations, status, alarms (OPC UA/MQTT/REST).
	•	CMMS/EAM: work orders from defects, PM schedules (AM vs PM).
	•	LMS/HRIS: workforce sync, certifications, leave/shift.
	•	Calendars & SSO: SCIM users/groups; iCal feeds for LSW/DDS.

Note: We explicitly avoid digitizing sub‑optimal flows. The Optimize‑Before‑Digitize Gate (Core Admin) helps discover foundational issues first, preventing the “automated flaws” problem described in case studies.  ￼

⸻

11) Build Plan (incremental, production‑safe)

11.1 Foundations (Month 0–2)
	•	Core cluster (K8s), Kafka, Postgres, Keycloak, OPA, Temporal, Observability stack.
	•	AuthN/Z, tenant scaffolding, audit ledger.
	•	Data contracts v1 for Equipment, Run/Stop, SOP, Skills.
	•	Edge Gateway with OPC UA ingestion, Store&Forward.

11.2 RTT Basics (Month 2–4)
	•	Floor: oee, dds, dms, andon minimal viable modules; DDS workflow & board.
	•	People: skills minimal (matrix & proficiency), training (OPL basics).
	•	SOP: runtime executor read‑only (import SOPs).
	•	Analytics: OEE pipeline; Unplanned stop focus dashboards.

This stage aligns with Run‑to‑Target “few items that matter,” enabling standardized DDS with loss focus (see P&G slides on RTT deployment and standardized DDS).  ￼

11.3 TPM & Centerlines (Month 4–6)
	•	Floor: centerlines, cil, defects + DMAIC template; changeover workflow.
	•	People: lsw (gemba planner), appraisals (link to improvement).
	•	SOP authoring + e‑sign.
	•	Analytics: centerline drift, AM adherence, FPY.

TPM digitization is guided by AM/CIL/OPL patterns shown in industry guides and connected worker tooling; we integrate one‑point lessons and digital SOPs directly into runtime tasks.  ￼  ￼

11.4 Quality, HSE & Advanced CI (Month 6–9)
	•	Floor: quality (SPC, NCR/CAPA), hse (audits, near‑miss), lossmap.
	•	People: advanced training & certification cycles; Learn‑Do‑Teach analytics.
	•	AI agents: suggest actions in DDS; skills‑aware scheduling.

11.5 Scale‑out, Integrations & Citizen Dev (Month 9+)
	•	ERP/MES/CMMS connectors hardened; multi‑site rollouts.
	•	Low‑code “App Studio” for site apps (forms→workflows), echoing citizen developer patterns to accelerate value.  ￼

⸻

12) Data Model (selected tables)

equipment

column	type	notes
equipment_id (PK)	uuid	
site_id	text	
line_id	text	
make_model	jsonb	
criticality	smallint	(1–5)
centerline_id	uuid	current CL set

centerline_param

column	type	notes
centerline_id	uuid	FK
name	text	e.g., seamer_torque
spec_low/high	numeric	
unit	text	
control_plan	jsonb	sampling, alarms

cil_task

column	type	notes
task_id (PK)	uuid	
equipment_id	uuid	
step_list	jsonb	steps with hazards/PPE
cadence	text	daily/weekly/shift
offline_bundle	boolean	included in PWA pack

skill_matrix_entry
| user_id | skill_id | level | valid_until | evidence_ref |

sop_version
| sop_id | version | status | html_bundle_ref | hazards | approvals |

(Complete schema packs are published in the Core Admin console.)

⸻

13) Observability & SRE
	•	Golden signals: latency, traffic, errors, saturation per service; custom domain SLIs (DDS completion on time %, AM adherence, centerline drift MTTR).
	•	Error budgets: each service maps SLO → error budget; change policy tied to budget depletion.
	•	Tracing: end‑to‑end spans across PWA↔BFF↔services↔DB; baggage carries tenant_id, site_id.
	•	Synthetic monitors: DDS open/close, SOP run, Andon raise.

⸻

14) Security Engineering & Audits
	•	Threat model: STRIDE per service; abuse cases for e‑sign, SOP tamper, and policy bypass.
	•	Static & dependency scanning: CodeQL, Trivy; container SBOMs.
	•	Runtime policies: seccomp, AppArmor, minimal base images; network policies (deny all, allowlists).
	•	Privacy: PII minimization; access reason logging for HR records.

⸻

15) Developer Experience & CI/CD
	•	Git: trunk‑based; short‑lived feature branches; conventional commits; semantic versioning.
	•	CI: unit + contract tests; consumer‑driven contract tests between services (PACT).
	•	CD: progressive delivery (blue/green → canary via Argo Rollouts); migrations with sqitch.
	•	Fixtures & Sandboxes: synthetic plant (simulated OPC UA server), demo datasets; load tests (k6).

⸻

16) Quality System in the Software
	•	Standard Work is code: SOPs/OPLs are versioned artefacts with approvals and e‑sign; visual management ensures leaders see adherence and gaps (aligns to connected worker/IWS).  ￼  ￼
	•	DDS/DMS are first‑class: standardized agendas/timeboxes mirror best practice (see standardized DDS meeting template).  ￼
	•	CI Engine: PDCA/DMAIC with templates, analytics, and sustainment controls; learnings become SOP updates (closing the loop).  ￼  ￼

⸻

17) UX Blueprints (Floor highlights)
	•	DDS Board: “Yesterday/Today/Tomorrow” panel, safety/quality/throughput/service widgets, unplanned stops sparkline, actions lane, timer. (Matches the daily planning emphasis: define what’s needed for an “uneventful day”.)  ￼
	•	Loss Map: area map with colored chips by category (safety/quality/effort/inventory), inspired by the loss map visuals; click → DMAIC card.  ￼
	•	AM/CIL: checklists with photo capture; defect creation inline; OPL suggestions if repeated findings (ties to TPM & connected worker).  ￼  ￼
	•	Centerlines: live gauges; “Restore to Standard” one‑tap; drift alerts; pre‑run “Quality to Start”.  ￼

⸻

18) Governance & Cultural Features
	•	LSW planner: daily/weekly/monthly leader routines with automated proof of presence (BLE/NFC at “gemba”), micro‑coaching prompts, and sustainment reviews, reflecting LSW steps and gemba’s value.  ￼
	•	Learn‑Do‑Teach telemetry: leaders see how training converts to results; skills and SOP adherence improve outcomes (as highlighted in IWS connected worker guidance).  ￼
	•	Optimize Gate: pre‑digitization checklist ensures we standardize & stabilize first—fix the foundation before adding floors.  ￼

⸻

19) Acceptance Criteria (E2E)
	1.	RTT loop: After 4 weeks live, unplanned stops data drives ≥ 1 structured DMAIC per line; DDS actions are closed ≥ 85% on time; centerline restore MTTR < 15 minutes. (RTT focus on unplanned stops as a lever.)  ￼
	2.	TPM loop: AM/CIL adherence ≥ 90%; defects per AM drop ≥ 20% in 60 days; OPL usage evident.  ￼
	3.	LSW loop: 100% leaders with LSW schedules; ≥ 3 gemba/week each; action follow‑ups recorded.  ￼
	4.	SOP loop: 100% critical tasks executed from digital SOPs; cycle‑time variance reduced ≥ 10%; audits found in ledger.  ￼
	5.	CI loop: ≥ 2 DMAICs/line/quarter; sustained controls documented and monitored.  ￼  ￼

⸻

20) Appendix — Mappings & Citations
	•	IWS pillars ↔ MS5.0 modules (examples)
	•	AM/PM/PM² (TPM): Floor CIL/Defects/Breakdown, Centerlines; People Training/OPL.  ￼
	•	LDR, DMS, DDS: People LSW; Floor DMS/DDS boards; Core Workflow. (See standardized DDS slides.)  ￼
	•	WPI/Lean: SOP author/runtime; Changeover; Visual management.  ￼  ￼
	•	FI/Six Sigma: DMAIC workflows & analytics.  ￼
	•	ET/Skills: skills matrices & Learn‑Do‑Teach telemetry.  ￼
	•	ENT/SN: Core Integrations & Data Mesh; Optimize gate.  ￼  ￼
	•	Visual references used
	•	RTT transitions & focus on unplanned stops; standardized DDS meeting; loss maps; eManufacturing foundations & citizen dev (Marc Winkelman deck, multiple slides).  ￼
	•	Connected worker components: daily management/DDS/CIL/Defect/Changeover/5S/Skills (IWS + connected worker overview, pages on components & benefits).  ￼
	•	LSW routines & gemba role (LSW explainer).  ￼
	•	TPM pillars & OPLs (TPM guide).  ￼
	•	SOP principles & adoption (Real‑world SOPs).  ￼
	•	Optimize before digitize rationale and examples (Digital Done Right).  ￼
	•	IWS pillars & principles for culture + enterprise (IWS backgrounder).  ￼
	•	Lean Six Sigma foundations—DMAIC/statistics (intro article).  ￼
	•	Continuous Improvement/PDCA & future tech (CI article).  ￼

⸻

Final notes for builders
	•	Decide, don’t drift. The choices above are opinionated so cross‑functional teams can ship with speed and confidence.
	•	Build the loops. DDS → Loss focus → Problem solving → Standard work → Skills → DDS. Productize these loops; everything else supports them.
	•	Make it visible. If leaders can’t “see” the work (visuals, audits, routes), they can’t coach. The software must pull them to the floor. (LSW & visual management principles.)  ￼  ￼

