Rename the no_show status to missed

Front desk staff found "no_show" confusing on the follow-up screen, so the status is now `missed`. Migration 002 renames existing rows (and back on rollback); `STATUSES` and `missedVisits` use the new name. Tests updated.
