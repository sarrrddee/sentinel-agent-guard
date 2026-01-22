# Sentinel Agent Guard

A permission and spending guard smart contract for AI agents on the Stacks blockchain. Sentinel Agent Guard enables owners to register AI agents with configurable spending limits per epoch, providing controlled fund access and comprehensive spending oversight for autonomous systems.

## Overview

Sentinel Agent Guard is a Clarity smart contract that implements a spending control system for AI agents. Owners register agents with daily spending limits that automatically reset after ~144 blocks (approximately 1 day), allowing secure and controlled fund access while maintaining complete transparency and audit trails.

## Features

✓ **Agent Registration** - Register AI agents with configurable spending limits per epoch  
✓ **Epoch-Based Limits** - Spending limits reset automatically every ~144 blocks (~1 day)  
✓ **Spending Control** - Agents can only spend up to their configured limit per epoch  
✓ **Agent Revocation** - Owners can instantly revoke agent permissions  
✓ **Automatic Epoch Reset** - Spending counters reset automatically when epoch expires  
✓ **Secure Fund Transfers** - STX transfers executed only within authorized limits  
✓ **Real-Time Status Tracking** - Query agent permissions and current spending status  

## Contract Functions

### Owner Functions

- `register-agent(agent, max-per-epoch)` - Register an AI agent with spending limit
  - `agent`: Principal address of the AI agent to authorize
  - `max-per-epoch`: Maximum amount agent can spend per epoch (in microSTX)
  - Returns: Success confirmation
  - Validates that max-per-epoch is greater than zero

- `revoke-agent(agent)` - Revoke an agent's permissions
  - `agent`: Principal address of the agent to disable
  - Prevents revoked agents from executing any spending
  - Can be called at any time to immediately disable access
  - Returns: Success confirmation or ERR-NOT-AUTHORIZED if agent not found

### Agent Functions

- `agent-spend(owner, recipient, amount)` - Execute a spend transaction
  - `owner`: Principal address of the owner authorizing the spend
  - `recipient`: Principal address of the fund recipient
  - `amount`: Amount to transfer in microSTX
  - Transfers funds from owner to recipient if within limits
  - Automatically resets epoch if 144+ blocks have passed
  - Returns: Success confirmation or error code

### Read-Only Functions

- `get-agent(owner, agent)` - Query agent permissions and spending status
  - Returns: max-per-epoch, spent-this-epoch, epoch-start block height, active status
  - Returns none if agent not registered for owner

## State Management

### Storage Maps
- **agents**: Stores agent metadata keyed by (owner, agent) pair
  - `max-per-epoch`: Spending limit per epoch in microSTX
  - `spent-this-epoch`: Amount already spent in current epoch
  - `epoch-start`: Block height when current epoch started
  - `active`: Boolean indicating whether agent is active (not revoked)

### Configuration Constants
- **EPOCH-LENGTH**: Set to 144 blocks (~1 day on Stacks blockchain)

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | ERR-NOT-OWNER | Caller is not the agent owner |
| u101 | ERR-NOT-AUTHORIZED | Agent not found or not authorized for caller |
| u102 | ERR-LIMIT-EXCEEDED | Spending would exceed epoch limit |
| u103 | ERR-AGENT-REVOKED | Agent has been revoked and cannot spend |
| u104 | ERR-INVALID-AMOUNT | Amount is zero or invalid |

## Usage Example

```clarity
;; 1. Owner registers an AI agent with 1 STX per day limit
(contract-call? .sentinel-agent-guard 
  register-agent 
  'SP1AGENT123... 
  u1000000  ;; 1 STX in microSTX
)
;; Returns: (ok true)

;; 2. Query agent's permissions and spending status
(contract-call? .sentinel-agent-guard 
  get-agent 
  'SP1OWNER456... 
  'SP1AGENT123...
)
;; Returns: {
;;   max-per-epoch: u1000000,
;;   spent-this-epoch: u0,
;;   epoch-start: u12345,
;;   active: true
;; }

;; 3. Agent executes a spend (within limit)
(contract-call? .sentinel-agent-guard 
  agent-spend 
  'SP1OWNER456...      ;; owner
  'SP1RECIPIENT789...  ;; recipient
  u500000              ;; 0.5 STX
)
;; Returns: (ok true) - Transfer successful

;; 4. Query updated spending status
(contract-call? .sentinel-agent-guard 
  get-agent 
  'SP1OWNER456... 
  'SP1AGENT123...
)
;; Returns: {
;;   max-per-epoch: u1000000,
;;   spent-this-epoch: u500000,  ;; Updated
;;   epoch-start: u12345,
;;   active: true
;; }

;; 5. Owner revokes agent access
(contract-call? .sentinel-agent-guard 
  revoke-agent 
  'SP1AGENT123...
)
;; Returns: (ok true) - Agent can no longer spend
