# One authoritative Project registry

ADR 0006 established global repository decisions, global Projects, and
machine-local checkout paths. Its initial layout repeated repository identity
in three places: `repositories.json`, `projects/<id>/project.json`, and each
machine path cache. That duplication created drift during the first private
Sync Repo migration and made identity harder to reason about.

## Decision

`repositories.json` is the only authority for portable Git identity. It is a
direct object keyed by credential-free canonical origin:

```json
{
  "github.com/example/project": {
    "status": "tracked",
    "project": "project"
  },
  "github.com/example/ignored": {
    "status": "ignored"
  }
}
```

`projects/<id>/` contains only the Project's bounded `handoffs/` directory.
The directory name is the Project ID; `project.json` is removed.

`machines/<machine>/projects.json` remains a disposable path cache, reduced to
one fact:

```json
{
  "paths": {
    "/absolute/checkout": {
      "project": "project"
    }
  }
}
```

Satchel always reads the checkout's current Git origin and consults the global
registry before rebuilding a network repository's path cache. A folder name
only suggests a new Project ID. Different origins with the same basename get
unique IDs; the same canonical origin on any machine shares one Project.
Repositories without a portable origin can be linked only by explicitly
naming an existing Project ID.

Satchel validates the registry, Project directories, and every machine cache
before using or syncing them. Two origins cannot claim one Project ID,
tracked entries must point to an existing Project, ignored entries cannot
carry a Project, and identity conflicts are reported rather than repaired.

## Consequences

- Repository identity has one authoritative representation.
- Ignored decisions remain global without creating empty Project directories.
- Machine caches can be deleted and rebuilt without losing identity.
- The schema is intentionally incompatible with the earlier duplicated form;
  this project used a one-time private Sync Repo migration instead of carrying
  compatibility code.

This ADR refines ADR 0006.
