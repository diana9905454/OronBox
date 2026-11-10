# OronBox Resource Publishing and Review Rules

Version: 1.0.0
Effective date: 2026-07-19
Last updated: 2026-07-19

These Rules apply to the OronBox resource catalog and to resources submitted through OronBox to BandBBS or AstroBox-Repo. The content standards apply to every OronBox resource.

## Chapter 1 — Scope

These Rules cover resource names, descriptions, changelogs and tags; applications, miniprograms, watchfaces and installation files; icons, covers, screenshots, previews and audio; manifests, README files, licenses and third-party components; device support and file bindings; comments, appeals, rights evidence and review communication; and related BandBBS resources, GitHub repositories, commits and pull requests.

## Chapter 2 — Submission requirements

### 2.1 Platform and type

1. The actual platform and type must match the selection made when the resource was created.
2. Extensions, headers, manifests, or metadata must not be altered to disguise a resource.
3. Files are rejected when server analysis identifies a conflicting platform or type.

### 2.2 Images

1. At least one preview is required.
2. Images must represent the actual resource and must not be irrelevant, false, or misleading.
3. OronBox keeps the aspect ratio, limits each dimension to 1500 px, and converts images to WebP.
4. AstroBox publication requires a separately supplied square icon and 3:2 cover.
5. Protected trademarks, works, likenesses, or other material must not be used without authorization.

### 2.3 Files and devices

1. At least one valid resource file is required.
2. Every file must be bound to at least one supported device.
3. A file may support multiple devices and a revision may contain multiple files.
4. Device support claims require a reasonable testing or compatibility basis.
5. Known incompatible devices must not be marked as supported.

### 2.4 Metadata

Names, authorship, versions, package IDs, features, pricing, licenses, changelogs, and supported devices must be accurate. Publishers must not impersonate an official party or creator, hide material limitations or behavior, make deceptive claims, imitate another resource in a confusing manner, or manipulate discovery with excessive tags, keywords, or duplicates.

## Chapter 3 — Prohibited content and conduct

### 3.1 Unlawful and seriously inappropriate content

Resources must not contain or facilitate unlawful content; threats to public safety; obscene, sexually exploitative, or age-inappropriate content; extreme gore, abuse, violent threats, self-harm encouragement, or encouragement to harm others; defamation, harassment, stalking, doxxing, or malicious exposure of personal information; fraud, phishing, deception, or material omissions; unauthorized advertising, spam, malicious redirection, or artificial traffic; religious conflict, political mobilization, incitement of group conflict, or content likely to involve OronBox and related platforms in major political or public incidents; prohibited sanctions or export-control uses; or other publication-related content expressly prohibited by applicable law, BandBBS, or AstroBox.

### 3.2 Identity-based attacks, discrimination, and hate

Attacks against a person or group based on race, color, ethnicity, nationality, regional origin, religion, belief, sex, gender identity or expression, sexual orientation, age, disability, health condition, or a similar identity characteristic are prohibited.

Prohibited behavior includes slurs or dehumanizing language; claims that a group is inherently inferior, dangerous, dirty, or undeserving of equal rights; encouragement of exclusion, segregation, expulsion, discrimination, or deprivation of rights; threats, praise, justification, or incitement of violence; such conduct through names, features, images, audio, text, easter eggs, or updates; and attempts to disguise clear attacks as jokes, irony, abstraction, tests, or personal opinions.

Good-faith discussion, criticism, satire, research, or artistic expression concerning history, policy, religion, culture, or society is not automatically prohibited. The decisive question is whether the content attacks identity itself through insult, discrimination, hate, or incitement to harm.

### 3.3 Intellectual property and impersonation

The following are prohibited: unauthorized copying, modification, repackaging, or redistribution; misappropriation of code, images, fonts, music, icons, covers, screenshots, trademarks, or text; license violations, concealed sources, or removed attribution; impersonation; forged licenses, authorization, purchase records, source projects, or development records; trivial modifications presented as original work; and tools dedicated to bypassing lawful licensing, payment, signatures, access controls, or technical protection, except compatibility research expressly permitted by law.

Creators submitting AI-generated content must disclose it and remain responsible for rights defects, infringement risks, and compliance of the generated material.

### 3.4 Security and malicious behavior

Resources must not contain or assist malware, ransomware, backdoors, destructive code, credential or data theft, undisclosed collection or sharing, exploitation of systems or services, bypass of permissions or controls, forged requests, denial-of-service attacks, undisclosed remote-code execution, deceptive high-risk permissions, concealed payloads, or material assistance for account theft, fraud, infringement, hate attacks, or platform abuse.

### 3.5 Privacy and data handling

Resources processing user data must clearly disclose the data, purpose, method, and destination; request only necessary permissions; obtain consent when legally required; provide stop, deletion, or withdrawal controls; use reasonable safeguards; avoid undisclosed advertising, profiling, sale, or unrelated sensitive data; and not use BandBBS, GitHub, or OronBox data to create unauthorized relationship graphs.

### 3.6 Material facilitation

A creator cannot avoid responsibility merely because the resource does not directly perform the prohibited act. Resources, plugins, scripts, tutorials, interfaces, and services must not materially facilitate unlawful conduct, infringement, discrimination, hate, fraud, data theft, account attacks, or platform abuse.

## Chapter 4 — Quality and compatibility

Resources must provide the basic functions described and must not be broken, empty, or placeholders. Known risks of bricking, data loss, abnormal battery drain, crash loops, or comparable harm must be prominently disclosed; unmanageable risks prohibit publication.

Updates must disclose removal of core features, new high-risk permissions, or pricing changes. Pricing, licensing, and limitations must be accurate. AstroBox metadata must follow the then-current AstroBox-Repo format.

## Chapter 5 — Review process

### 5.1 States

Resource revisions use three independent sets of states:

- **Revision state**: draft, submitted, approved, rejected. Submitting a new revision marks the previous one as superseded.
- **Management state**: visible, suspended, frozen. Suspended and frozen resources stop being displayed and downloadable.
- **Publication state** (external publication): pending, running, reviewing, published, failed, cancelled.

### 5.2 Review scope

OronBox may inspect platform, type, format, package ID, version, device bindings, images, descriptions, malicious behavior, high-risk behavior, third-party components, licenses, identity and ownership disputes, content standards, and external-platform requirements.

### 5.3 Outcomes

1. **Approved:** the revision enters the public OronBox catalog and user-selected external publication jobs are started.
2. **Changes requested:** specified issues must be corrected before publication.
3. **Rejected:** primary reasons are provided; the creator may revise, resubmit, or appeal.
4. **Emergency suspension or delisting:** used for serious risks found after publication.

Comments are screened automatically and then reviewed by humans. Serious account sanctions receive human review.

## Chapter 6 — Enforcement

These measures supplement the management powers in Section 6 of the OronBox Terms and Disclaimer.

Measures at the revision level include warnings, required corrections, rejection, review suspension, display or download suspension, and version delisting or removal.

Measures at the resource level include resource delisting, blocked new revisions, withdrawal of the current public revision, stopped CDN distribution, and cancelled or suspended external synchronization.

Measures at the creator level include suspended resource creation, suspended submission or updates, renewed identity or rights verification, suspended BandBBS publication, suspended GitHub publication, and suspended or revoked creator eligibility.

Measures at the account level include restricted features, forced session termination, temporary account suspension, permanent bans, and action against accounts used to evade sanctions.

For external platforms, OronBox may cancel pending publication jobs, stop automatic retries, request action from BandBBS, report resources, repositories, or pull requests to AstroBox-Repo maintainers, report abuse, security, or infringement to GitHub, and review its own decisions in light of third-party action.

## Chapter 7 — Enforcement factors

OronBox considers the nature and real-world harm; intent and evasion; reach and duration; prior violations; voluntary stopping, repair, and disclosure; cooperation; forged evidence or concealment; repeated violations; risks to accounts, devices, data, or platforms; and decisions of platforms, rights holders, or authorities.

There is no mechanical first-warning rule. Malware, credential theft, severe hate or violence, major infringement, fraud, token abuse, and platform attacks may result in permanent action on the first incident.

## Chapter 8 — Emergency measures

For apparent illegality, malware, account or data danger, serious infringement, severe identity attacks, violent threats, platform attacks, or another urgent risk, OronBox may immediately stop downloads, delist a resource, suspend review, terminate external jobs, revoke sessions, temporarily disable an account, preserve necessary evidence, and report to relevant platforms or security teams.

Users will be notified within a reasonable time where doing so does not compromise investigation or risk control.

## Chapter 9 — Evasion

Users must not evade action through replacement BandBBS or GitHub accounts, borrowed identities, changed IDs or hashes, alternate official-service interfaces, or substantially equivalent conduct.

## Chapter 10 — Notice, remediation, and appeal

Notices normally identify the affected resource or account, rule category, measure, start time, duration, and appeal route. OronBox may withhold details that would expose detection methods, endanger complainants, compromise security work, or facilitate evasion.

Creators may submit factual explanations, rights evidence, technical analysis, corrected versions, account-compromise evidence, or other new evidence within 15 calendar days. A justified extension may be requested before the deadline.

Review may uphold, reduce, remove, conditionally restore, or increase a measure. Restoring a resource does not automatically restore every external publication privilege. Third-party decisions must be appealed through the relevant platform.

## Chapter 11 — Changes to these Rules

OronBox may update these Rules for legal requirements, package formats, security risks, device platforms, or third-party rules. Creators will be notified of material changes to content standards or sanctions.

Urgent safety rules may apply immediately. For other material changes, OronBox will provide a reasonable transition period of at least 15 days; resources not updated after that period may have public distribution restricted.

## Chapter 12 — Contact

- Official instance operator: OronBox Operations Team
- Publishing, complaints, and appeals: t3164473115@163.com
- Public discussion: <https://github.com/OronCanopy/OronBox/discussions>
