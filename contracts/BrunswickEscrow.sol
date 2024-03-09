// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

interface IERC20 {
  function transfer(address to,uint value) external returns(bool);
  function balanceOf(address owner) external view returns(uint);
  function transferFrom(address from,address receiver,uint amount) external ;
}

contract BrunswickEscrow is ContractMetadata {
  enum TaskStatus { 
    Undefined, 
    Created, 
    Vested, 
    Assigned, 
    Arbitration, 
    Completed, 
    Cancelled, 
    Resolved
   }
  
  struct Task{
    TaskStatus status;
    address address_owner;
    address address_worker;
    address address_mediator;
    address address_equity;
    uint amount_equity;
    uint amount_cash;
    uint time_duration;
    uint time_deadline;
    bool flag_autorelease;
    bool flag_autoassign;
  }
  
  address public g__SiteAuthority;
  
  mapping(address => bool) public g__SiteSupport;
  
  address g__SiteCashAddress;
  
  mapping(string => Task) public g__TaskLookup;
  
  string [] public g__TaskArray;
  
  enum TaskEventType { 
    Create, 
    EditCreated, 
    Vest, 
    EditVested, 
    Cancel, 
    Assign, 
    Complete, 
    Release, 
    Forfeit, 
    Dispute, 
    Resolve
   }
  
  event TaskEvent(TaskEventType event_type,string event_id,address event_address);
  
  constructor(address cash_address) {
    g__SiteAuthority = msg.sender;
    g__SiteCashAddress = cash_address;
  }
  
  function _canSetContractURI() internal view virtual override returns (bool){
      return msg.sender == g__SiteAuthority;
  }
  
  function ut__block_time(uint delay) internal view returns(uint) {
    return delay + block.timestamp;
  }
  
  function ut__assert_admin(address user_address) internal view {
    require(
      (user_address == g__SiteAuthority) || g__SiteSupport[user_address],
      "Site admin only."
    );
  }
  
  function ut__assert_owner(string memory task_id,address address_caller) internal view {
    require(
      g__TaskLookup[task_id].address_owner == address_caller,
      "Task owner only."
    );
  }
  
  function site__change_authority(address new_authority) external {
    require(msg.sender == g__SiteAuthority,"Site authority only.");
    g__SiteAuthority = new_authority;
  }
  
  function site__add_support(address user) external {
    require(msg.sender == g__SiteAuthority,"Site authority only.");
    g__SiteSupport[user] = true;
  }
  
  function site__remove_support(address user) external {
    ut__assert_admin(msg.sender);
    delete g__SiteSupport[user];
  }
  
  function site__task_create(string memory task_id,address address_owner,address address_mediator,address address_equity,uint amount_equity,uint amount_cash,uint time_duration,bool flag_autorelease,bool flag_autoassign) external {
    require(
      TaskStatus.Undefined == g__TaskLookup[task_id].status,
      "Task already exists."
    );
    ut__assert_admin(msg.sender);
    Task memory task = Task({
      time_duration: time_duration,
      address_worker: address(0),
      address_equity: address_equity,
      amount_equity: amount_equity,
      flag_autoassign: flag_autoassign,
      status: TaskStatus.Created,
      flag_autorelease: flag_autorelease,
      address_mediator: address_mediator,
      time_deadline: 0,
      amount_cash: amount_cash,
      address_owner: address_owner
    });
    g__TaskArray.push(task_id);
    g__TaskLookup[task_id] = task;
    emit TaskEvent(TaskEventType.Create,task_id,address_owner);
  }
  
  function owner__task_edit_created(string memory task_id,uint amount_equity,uint amount_cash,uint time_duration,bool flag_autorelease,bool flag_autoassign) external {
    ut__assert_owner(task_id,msg.sender);
    require(
      TaskStatus.Created == g__TaskLookup[task_id].status,
      "Task not created"
    );
    g__TaskLookup[task_id].amount_equity = amount_equity;
    g__TaskLookup[task_id].amount_cash = amount_cash;
    g__TaskLookup[task_id].time_duration = time_duration;
    g__TaskLookup[task_id].flag_autorelease = flag_autorelease;
    g__TaskLookup[task_id].flag_autoassign = flag_autoassign;
    emit TaskEvent(TaskEventType.EditCreated,task_id,msg.sender);
  }
  
  function owner__task_vest(string memory task_id) external {
    ut__assert_owner(task_id,msg.sender);
    require(
      TaskStatus.Created == g__TaskLookup[task_id].status,
      "Task not created"
    );
    address address_equity = g__TaskLookup[task_id].address_equity;
    uint amount_equity = g__TaskLookup[task_id].amount_equity;
    uint amount_cash = g__TaskLookup[task_id].amount_cash;
    if(0 < amount_equity){
      IERC20 erc20_equity = IERC20(address_equity);
      erc20_equity.transferFrom(msg.sender,address(this),amount_equity);
    }
    if(0 < amount_cash){
      IERC20 erc20_cash = IERC20(g__SiteCashAddress);
      erc20_cash.transferFrom(msg.sender,address(this),amount_cash);
    }
    g__TaskLookup[task_id].status = TaskStatus.Vested;
    emit TaskEvent(TaskEventType.Vest,task_id,msg.sender);
  }
  
  function owner__task_edit_vested(string memory task_id,uint16 time_duration,bool flag_autorelease,bool flag_autoassign) external {
    ut__assert_owner(task_id,msg.sender);
    require(
      TaskStatus.Vested == g__TaskLookup[task_id].status,
      "Task not vested"
    );
    g__TaskLookup[task_id].time_duration = time_duration;
    g__TaskLookup[task_id].flag_autorelease = flag_autorelease;
    g__TaskLookup[task_id].flag_autoassign = flag_autoassign;
    emit TaskEvent(TaskEventType.EditVested,task_id,msg.sender);
  }
  
  function ut__transfer_to(string memory task_id,address address_payee,address address_equity,uint payout_equity,uint payout_cash) internal {
    if(0 < payout_equity){
      IERC20 erc20_equity = IERC20(address_equity);
      erc20_equity.transfer(address_payee,payout_equity);
    }
    if(0 < payout_cash){
      IERC20 erc20_cash = IERC20(g__SiteCashAddress);
      erc20_cash.transfer(address_payee,payout_cash);
    }
  }
  
  function ut__assign_to(string memory task_id,address address_worker) internal {
    uint time_duration = g__TaskLookup[task_id].time_duration;
    g__TaskLookup[task_id].address_worker = address_worker;
    g__TaskLookup[task_id].time_deadline = (block.timestamp + time_duration);
    g__TaskLookup[task_id].status = TaskStatus.Assigned;
    emit TaskEvent(TaskEventType.Assign,task_id,address_worker);
  }
  
  function owner__task_cancel(string memory task_id) external {
    ut__assert_owner(task_id,msg.sender);
    require(
      TaskStatus.Vested == g__TaskLookup[task_id].status,
      "Task not vested"
    );
    address address_equity = g__TaskLookup[task_id].address_equity;
    uint amount_equity = g__TaskLookup[task_id].amount_equity;
    uint amount_cash = g__TaskLookup[task_id].amount_cash;
    ut__transfer_to(task_id,msg.sender,address_equity,amount_equity,amount_cash);
    g__TaskLookup[task_id].status = TaskStatus.Cancelled;
    emit TaskEvent(TaskEventType.Cancel,task_id,msg.sender);
  }
  
  function owner__task_assign(string memory task_id,address address_worker) external {
    ut__assert_owner(task_id,msg.sender);
    require(
      TaskStatus.Vested == g__TaskLookup[task_id].status,
      "Task not vested"
    );
    ut__assign_to(task_id,address_worker);
  }
  
  function owner__task_complete(string memory task_id) external {
    ut__assert_owner(task_id,msg.sender);
    require(
      TaskStatus.Assigned == g__TaskLookup[task_id].status,
      "Task not assigned"
    );
    address address_equity = g__TaskLookup[task_id].address_equity;
    uint amount_equity = g__TaskLookup[task_id].amount_equity;
    uint amount_cash = g__TaskLookup[task_id].amount_cash;
    ut__transfer_to(task_id,msg.sender,address_equity,amount_equity,amount_cash);
    g__TaskLookup[task_id].status = TaskStatus.Cancelled;
    emit TaskEvent(TaskEventType.Complete,task_id,msg.sender);
  }
  
  function worker__task_assign(string memory task_id) external {
    require(
      TaskStatus.Vested == g__TaskLookup[task_id].status,
      "Task not vested"
    );
    require(
      g__TaskLookup[task_id].flag_autoassign,
      "Task not autoassignable"
    );
    ut__assign_to(task_id,msg.sender);
  }
  
  function worker__task_forfeit(string memory task_id) external {
    require(
      TaskStatus.Assigned == g__TaskLookup[task_id].status,
      "Task not assigned"
    );
    require(
      g__TaskLookup[task_id].address_worker == msg.sender,
      "Task worker only."
    );
    g__TaskLookup[task_id].status = TaskStatus.Vested;
    g__TaskLookup[task_id].address_worker = address(0);
    g__TaskLookup[task_id].time_deadline = 0;
    emit TaskEvent(TaskEventType.Forfeit,task_id,msg.sender);
  }
  
  function trigger__task_release(string memory task_id) external {
    require(
      TaskStatus.Assigned == g__TaskLookup[task_id].status,
      "Task not assigned"
    );
    require(
      g__TaskLookup[task_id].flag_autorelease,
      "Task not autorelease"
    );
    require(
      g__TaskLookup[task_id].time_deadline < block.timestamp,
      "Task not overdue"
    );
    address address_worker = g__TaskLookup[task_id].address_worker;
    address address_equity = g__TaskLookup[task_id].address_equity;
    uint amount_equity = g__TaskLookup[task_id].amount_equity;
    uint amount_cash = g__TaskLookup[task_id].amount_cash;
    ut__transfer_to(task_id,address_worker,address_equity,amount_equity,amount_cash);
    emit TaskEvent(TaskEventType.Release,task_id,address_worker);
  }
  
  function trigger__task_dispute(string memory task_id) external {
    require(
      TaskStatus.Assigned == g__TaskLookup[task_id].status,
      "Task not assigned"
    );
    require(
      (g__TaskLookup[task_id].address_owner == msg.sender) || (g__TaskLookup[task_id].address_worker == msg.sender),
      "Task participants only."
    );
    g__TaskLookup[task_id].status = TaskStatus.Arbitration;
    emit TaskEvent(TaskEventType.Dispute,task_id,msg.sender);
  }
  
  function mediator__task_resolve(string memory task_id,uint payout_equity,uint payout_cash) external {
    require(
      (g__TaskLookup[task_id].address_mediator == msg.sender),
      "Task mediator only."
    );
    require(
      g__TaskLookup[task_id].status == TaskStatus.Arbitration,
      "Task not arbitration"
    );
    address address_owner = g__TaskLookup[task_id].address_owner;
    address address_worker = g__TaskLookup[task_id].address_worker;
    address address_equity = g__TaskLookup[task_id].address_equity;
    uint amount_equity = g__TaskLookup[task_id].amount_equity;
    uint amount_cash = g__TaskLookup[task_id].amount_cash;
    ut__transfer_to(task_id,address_owner,address_equity,payout_equity,payout_cash);
    ut__transfer_to(
      task_id,
      address_worker,
      address_equity,
      amount_equity - payout_equity,
      amount_cash - payout_cash
    );
    g__TaskLookup[task_id].status = TaskStatus.Resolved;
    emit TaskEvent(TaskEventType.Resolve,task_id,msg.sender);
  }
}