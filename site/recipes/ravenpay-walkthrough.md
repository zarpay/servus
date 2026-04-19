# RavenPay Walkthrough

RavenPay is the handbook's fictional example system. This walkthrough ties together the main Servus ideas by following one action from request to follow-up work.

## Scenario

The Crown needs to transfer gold to Castle Black and send a raven receipt afterward. The transfer must fail cleanly if the crown account lacks funds, must log its execution, and should emit an event so the receipt flow remains decoupled.

## Service boundary

`Treasury::TransferGold::Service` owns the transfer itself. Its job is to validate the request, perform the movement of funds, and return a standard response.

## Guard usage

An `OpenAccountGuard` can ensure that both participating treasury accounts are active before the transfer proceeds. That keeps shared preconditions out of the middle of the service body.

## Event emission

On success, the transfer can emit `:gold_transferred`. A dedicated handler can then trigger `Ravens::DispatchReceipt::Service` so the receipt flow stays outside the original action.

## Why the example matters

The example is intentionally small, but it shows the Servus model clearly. One service owns the named action. Guards express reusable policy. Events fan out follow-up behavior. Tests can lock each part down independently.
