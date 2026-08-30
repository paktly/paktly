# Shared-expense ledger

The PostgreSQL journal is immutable and double-entry. `journal_entries` describe an economic event; `journal_lines` carry its debits and credits. Application invariant tests require every entry to balance.

For an expense paid by Alice and shared with Bob:

```text
Bob member balance     debit  $40
Alice member balance  credit $40
```

Positive net (`credits - debits`) means the member is owed money. Negative net means the member owes money.

Edits and deletes create reversal entries by swapping every prior debit and credit. Debt simplification operates only on resulting net positions and returns suggested settlement paths. It never changes expenses or journal history.

Offline clients generate the operation ID before sending. The database uniqueness constraint makes a retry safe even after the client loses the response.
