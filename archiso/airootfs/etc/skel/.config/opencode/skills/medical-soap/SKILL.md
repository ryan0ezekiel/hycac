---
name: medical-soap
repo: mumble_monster/medical-notes
description: >
  Medical SOAP note generation from natural dictation. Use this skill when
  the user describes a patient encounter, OPD visit, or case history and
  wants it formatted as a structured full-length SOAP note. Also handles
  medical case presentation best practices and clinical reasoning
  documentation. Triggered by keywords: SOAP, OPD, patient, case,
  history, dictation, clinical note, medical note.
---

# Medical SOAP Note Generation

Generate full-length, structured SOAP notes from the user's natural dictation or fragmented descriptions of patient encounters. This skill follows best practices from medical education (UW, OSU, Columbia, BMJ, StatPearls) for history-taking, clinical reasoning, and case presentation.

## Core workflow

1. User describes a patient encounter however it comes out — dictation style, bullet points, fragmented
2. Agent anonymizes all identifying details (names, IDs, addresses, phone numbers, specific dates other than year)
3. Agent reshapes into a full SOAP note following the template below
4. Agent saves to `~/medical-notes/opd-log.md` with a date-stamped entry

## SOAP Note Structure

### SUBJECTIVE

**ID / CC:** [Age/Sex] — [Chief complaint] × [duration]

**HPI:** Full chronological narrative. Use OLDCARTS framework:
- **O**nset — when and how it started (gradual/acute)
- **L**ocation — where exactly
- **D**uration — how long, intermittent/constant
- **C**haracter — quality (sharp, dull, burning, etc.)
- **A**ggravating/Alleviating — what makes it better/worse
- **R**adiation — does it spread
- **T**iming — progression, pattern
- **S**everity — scale, impact on function

Also capture: prior episodes, patient attribution, any treatment already tried.

**PMH:** Relevant past medical history only. Summarize chronic problems with: original diagnosis (date, presentation, diagnostic tests), current management and control level, complications, most recent objective measure.

**Medications:** List with dosages.

**Allergies:** List with reaction type.

**Family Hx:** Pertinent to presenting problem only.

**Social Hx:** Occupation, living situation, support system, habits (smoking, alcohol, substance use) — only as relevant.

**ROS:** Pertinent positives AND negatives by system. Key negatives that rule out dangerous alternatives are critical.

### OBJECTIVE

**Vitals:** BP, HR, RR, Temp, SpO2, BMI if relevant.

**General:** Appearance, distress level, build, nutrition.

**Exam:** Full examination of affected system(s) first, then other systems. Report all abnormal findings regardless of system. For systems not relevant to the chief concern, may summarize as "Normal."

**Labs/Imaging:** Relevant results with normal ranges noted.

### ASSESSMENT

**One-liner:** 2-3 sentence summary: epidemiology + duration + syndrome. This is a problem representation, not a closing argument. Keep it neutral — include key features from history and exam that define the case.

**Problem List:** Numbered list of all active problems.

**Differential:**
- Most likely diagnosis with supporting evidence from history and exam
- Alternative diagnoses with reasoning for why less likely

**Reasoning:** Brief clinical reasoning tying together key findings. This demonstrates the diagnostic thought process.

### PLAN

**Diagnostic:** Tests to order, consults needed, with rationale.

**Treatment:** Pharmacologic (generic names, doses, routes), non-pharmacologic, procedures.

**Education:** Key counseling points for the patient.

**Follow-up:** When to return, what to monitor, red flags to watch for.

## Time reference rules

- Use "X days/weeks prior to presentation" — never specific dates like "last Wednesday at 2 PM"
- Use "X days ago" for OPD visits
- Be consistent with the reference point throughout the note

## Anonymization rules

- Replace patient names with "[Patient]"
- Replace family member names with relationship (e.g., "[Spouse]", "[Son]")
- Replace specific dates (day/month) — keep year
- Replace addresses, phone numbers, hospital names, doctor names with generic placeholders
- Scramble but preserve: age, sex, occupation type (can be relevant)
- Do NOT scramble: symptoms, signs, diagnoses, medications, lab values — these are clinically essential

## File conventions

- All notes saved to: `~/medical-notes/opd-log.md`
- Each entry starts with a level-2 heading: `## YYYY-MM-DD — [Brief descriptor]`
- Append new entries to the end of the file
- If the file doesn't exist, create it with a header

## OPD workflow (fast)

For OPD visits where the user gives brief dictation:
1. Fill out the full SOAP template — do not skip sections even if sparse
2. Mark missing information as "[Not obtained]" rather than omitting
3. Ask clarifying questions only if critical information is genuinely ambiguous

## Delivery

- After saving, tell the user the file was updated
- Read back a brief summary of what was saved
- Offer to continue with the next case
