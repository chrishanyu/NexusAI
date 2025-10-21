# Memory Bank

This directory contains comprehensive documentation for the NexusAI project. These files are critical for maintaining context across development sessions and ensuring consistent understanding of the project's goals, architecture, and progress.

## Purpose

The Memory Bank serves as the **single source of truth** for project context. After every reset or new session, these files provide complete context about:
- What we're building and why
- How the system works
- What's been completed
- What's next to build
- Technical decisions and patterns

## File Structure

### Core Documentation (Required)

1. **`projectbrief.md`** - Foundation Document
   - Project overview and mission
   - Success criteria and constraints
   - Key principles and phases
   - Reference to other documentation

2. **`productContext.md`** - Product Vision
   - Why this project exists
   - Problems we're solving
   - User experience and journeys
   - Value propositions

3. **`techContext.md`** - Technical Stack
   - Technologies and dependencies
   - Development environment
   - Database schema
   - Technical decisions and rationale

4. **`systemPatterns.md`** - Architecture & Patterns
   - MVVM architecture details
   - Layer responsibilities
   - Key patterns (Optimistic UI, Real-Time Sync, Offline-First)
   - Data flow diagrams
   - Component relationships

5. **`activeContext.md`** - Current Work Focus
   - What we're building right now
   - Recent decisions
   - Active challenges
   - Next immediate steps
   - Open questions

6. **`progress.md`** - Progress Tracker
   - What's completed
   - What's in progress
   - What's not started
   - Known issues
   - Testing status
   - Milestones and metrics

## How to Use This Memory Bank

### Starting a New Session
1. Read `projectbrief.md` first - understand the mission
2. Read `activeContext.md` - know what's happening now
3. Read `progress.md` - understand current state
4. Reference `systemPatterns.md` and `techContext.md` as needed for implementation

### During Development
- Update `activeContext.md` when making decisions or facing challenges
- Update `progress.md` when completing work or discovering issues
- Reference `systemPatterns.md` for architectural guidance
- Reference `techContext.md` for technical details

### After Completing Work
- Mark items complete in `progress.md`
- Update `activeContext.md` with new focus
- Document new patterns in `systemPatterns.md` if discovered
- Add technical decisions to `techContext.md` if made

### Triggering Full Memory Bank Update
Use the command **"update memory bank"** to trigger a comprehensive review and update of all files. This ensures all documentation reflects the current state of the project.

## Document Dependencies

```
projectbrief.md (foundation)
    ├── productContext.md (why we exist)
    ├── systemPatterns.md (how it works)
    └── techContext.md (what we use)
            ↓
    activeContext.md (current focus)
            ↓
    progress.md (current state)
```

## External Documentation

The Memory Bank complements (but doesn't replace) these project docs:
- `../PRD.md` - Detailed product requirements document
- `../architecture.md` - Visual system architecture diagram
- `../building-phases.md` - PR breakdown and build phases
- `../README.md` - Setup instructions for developers

## Maintenance

### When to Update
- **activeContext.md** - Every work session (current focus changes)
- **progress.md** - Every PR completion or major milestone
- **systemPatterns.md** - When discovering new architectural patterns
- **techContext.md** - When making new technical decisions
- **productContext.md** - Rarely (product vision is stable)
- **projectbrief.md** - Very rarely (foundation doesn't change)

### Review Frequency
- Daily: `activeContext.md`, `progress.md`
- Weekly: All files (ensure consistency)
- After major milestones: Full review

## Version Control

Memory Bank files are committed to Git and versioned with the codebase. This ensures:
- Historical context is preserved
- Team members have consistent documentation
- Documentation evolves with the project

## Best Practices

1. **Keep it Current** - Outdated documentation is worse than no documentation
2. **Be Specific** - Vague statements don't help future sessions
3. **Link Context** - Reference other files and external docs
4. **Track Decisions** - Document why, not just what
5. **Be Honest** - Document issues, blockers, and unknowns

## Quick Reference

| Need to Know... | Read This File |
|----------------|----------------|
| Project mission and goals | `projectbrief.md` |
| Why we're building this | `productContext.md` |
| Tech stack and setup | `techContext.md` |
| Architecture patterns | `systemPatterns.md` |
| What to work on next | `activeContext.md` |
| Current status | `progress.md` |
| Detailed requirements | `../PRD.md` |
| System diagram | `../architecture.md` |
| Build phases | `../building-phases.md` |

---

**Last Updated:** October 21, 2025  
**Project Phase:** MVP Foundation Building  
**Current PR:** #2 - Core Models & Constants

