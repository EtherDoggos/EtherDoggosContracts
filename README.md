# EtherDoggosContracts

https://etherdoggos.com

Etherdoggos are cute animated doggos living on the Ethereum blockchain. They abide by the  ERC721 non-fungible token standard.
Owners of doggos can auction, breed, and race, and bet on their doggos on the ethereum blockchain. 

<h2> Doggo Racing: </h2>

<h3>Basic Goal:</h3>
Provide a way for owners of doggos to race them against other doggos and bet on the outcome.

<h3>Considerations:</h3>
I've considered several methods when it comes to how to make the racing/betting experience both fair and satisfying.
Some of the considerations were: <br>
-P2P decentralized betting vs centralized counter party(bookie)<br>
-Variable bet amounts vs fixed bet amounts<br>
-Global betting vs private betting<br><br>
In the spirit of decentralization, I've decided a centralized bookie is a bad idea. That leaved P2P betting but allowing variable bet amounts
would call for a very complicated system that could only really work with a large amount of users.
For these reasons, I've decided to implement P2P decentralized, global betting with fixed bet amounts for the first iteration of EtherDoggos.
This is achieved through racing queues.

<h3>How queues works:</h3>

First idea was to implement a lobby system with up to 4 doggos. When the lobby is full, the race commences among those 4 doggos and the winner
wins the sum of the ticketprices required to participate. This method has the advantage of relative simplicity but it is not quite fair to the 
lobby makers/early joiners since they do not get to see what doggos they will face whereas the last person joining a lobby has full knowledge.
<br><br>
To solve this issue, I've implemented racing queues. A queuetype contains information about:<br>
1. The length of time that the queue remains open for.<br>
2. The ticketprice in ETH required to participate in the queue(this is basically bet amount).<br>
3. The number of doggos in each race created from that queue.<br>

<br>
A queue of any of the preexisting queuetypes can be created by anyone who calls createQueue. Once created, up to 50 doggos can be signed up for that queue by calling joinQueue.
After the queue duration runs out, anyone can call closeQueue. At this point the blocknumber is recorded and a waiting period is initiated for a minimum of 4 blocks.
After the waiting period anyone can call resolveQueue. This is when the magic happens. The doggos are shuffled into sub-groups of up to 4 doggos. The subgroups are used
to create a race for each subgroup. At this point the queue did its job and a new one of the same queuetype can be created. The races remain to be resolved.
Resolve Queue is quite costly in terms of gas as it scales witht he number of doggos in the queue and so the caller of resolve queue is reinbursed from the fees charged by joinQueue.


<h3>How races works:</h3>
After a race is created it contains information about what doggos are in the race. At this point, anyone can call releaseRabbit on the race.
This will make a call for each doggo to our secret radar contract to determine the speed of the doggo. A doggos speed is mostly determined by its genes
but there is also some PRAND variation using the same blockhash as resolveQueue as a seed. Once all the doggos speeds are determined, 
the doggo with the highest speed is found and that is deemed the winner. The owner of that doggo can then call claimWinnings() on the race
to get his reward which is equal to  (# of participants in the race * ticketprice) - some small service fees. The leaderboard is updated accordingly.


<h3> Known Issues: </h3>
1. Randomness uses a future blockhash as a seed and so is not technically fully random. There is an exploit where miners could premine blocks
and not publish unless they win. However the relatively small sizes of the bets should make it unprofitable for a miner to forgo block rewards 
for the sake of this exploit.<br>
2. Even though anyone is able to call resolveQueue at anytime, if there are a shortage of people trying to do so or if our daemon is down there is the
possibility of an exploit by an attacker who waits to call it until the blockhash guarantees him the win. To combat this, the future blocknumber
of the blockhash used for PRAND should be set in stone. Then resolve queue would use that block no matter when it is called. Disadvantage here is
money would have to be returned to all participants if 256 blocks have passed and still noone has called resolveQueue.<br>
3. Ideally, queuetypes should be decentralized in the sense that anyone could make a queuetype  instead of having them preset.<br>
4. Fairly high gas cost on resolveQueue. Optimizations are in the works.<br>
5. Bleeding a small bit of eth which is unextractable. Probably a math error somewhere.<br>
