```markdown
# Freelance Marketplace Smart Contract

A simple Stacks (STX) escrow-based smart contract for managing freelance jobs and milestone-based payments.

## Overview

This contract enables:
- **Clients** to create jobs, set workers, define prices, and fund escrow
- **Workers** to submit milestones with descriptions and requested payments
- **Clients** to approve milestones, triggering automatic STX payouts to workers
- **Reputation tracking** for workers based on completed milestones

## Features

 Job creation with client-worker pairing  
 STX escrow funding with contract balance tracking  
 Milestone-based payment requests  
 Automatic reputation scoring for workers  
 Role-based access control (client/worker validation)  
 Input validation and error handling  

## Key Functions

### Public Functions

- **`create-job(worker, price)`** - Client creates a new job for a specified worker
- **`fund-job(job-id, amount)`** - Client transfers STX into contract escrow
- **`submit-milestone(job-id, amount, description)`** - Worker submits a milestone for approval
- **`approve-milestone(job-id, mid)`** - Client approves milestone and triggers worker payout

### Read-Only Functions

- **`get-job(job-id)`** - Query job details
- **`get-milestone(job-id, mid)`** - Query milestone details
- **`get-reputation(user)`** - Query user reputation score
- **`get-job-funded(job-id)`** - Query current escrow balance for a job

## Data Structures

### Jobs Map
```
{job-id: uint} -> {
  client: principal,
  worker: principal,
  price: uint,
  funded: uint,
  status: string-ascii (16)
}
```

### Milestones Map
```
{job-id: uint, mid: uint} -> {
  creator: principal,
  amount: uint,
  description: string-ascii (256),
  approved: bool,
  paid: bool
}
```

### Reputation Map
```
{user: principal} -> {score: int}
```

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 100 | `err-unauthorized` | Caller not authorized |
| 101 | `err-job-not-found` | Job does not exist |
| 102 | `err-insufficient-funds` | Insufficient escrow balance |
| 103 | `err-not-client` | Caller is not the job client |
| 104 | `err-not-worker` | Caller is not the assigned worker |
| 105 | `err-payment-failed` | STX transfer failed |
| 106 | `err-invalid` | Invalid input parameters |

## Usage Example

```clarity
;; 1. Client creates a job for worker with 100 STX price
(create-job 'ST2CY5V39NUAR67PM4YFVNEXFZWKS2HTMYOXSZ3H 100000000)

;; 2. Client funds the job with 100 STX
(fund-job 1 100000000)

;; 3. Worker submits a milestone for 50 STX
(submit-milestone 1 50000000 "Completed phase 1")

;; 4. Client approves the milestone (worker receives 50 STX)
(approve-milestone 1 1)
```

## Testing

Contract has been validated and tested:
-  Contract check: PASSED
-  Unit tests: PASSED

## Security Notes

**Demo Contract** - This is a simplified starter contract. Before production use:
- Conduct thorough security audit
- Add dispute resolution mechanisms
- Implement job cancellation logic
- Add time-based constraints (deadlines)
- Consider multi-sig for high-value transactions
- Add comprehensive access control for admin functions


MIT
