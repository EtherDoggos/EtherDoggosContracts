pragma solidity ^0.4.0;


contract DoggoMain {
	//ERC721 Functionality=========================================================================
	// Required methods
	function totalSupply() public view returns (uint256 total);
	function balanceOf(address _owner) public view returns (uint256 balance);
	function ownerOf(uint256 _tokenId) external view returns (address owner);
	function approve(address _to, uint256 _tokenId) external;
	function transfer(address _to, uint256 _tokenId) external;
	function transferFrom(address _from, address _to, uint256 _tokenId) external;
	
	// Events
	//event Transfer(address from, address to, uint256 tokenId);
	//event Approval(address owner, address approved, uint256 tokenId);

	
	//=============================================================================================
	//Extra  DoggoMain functionality
	function getModeFromDoggoId(uint256 doggoId) external returns (uint8); 
	function setModeByDoggoId(uint256 doggoId, uint8 mode) external;
	function getDNAFromDoggoId(uint256 doggoId) external returns(bytes32);
	function getCFOAddress() external returns(address);
}

//secret contract used to measure speed of doggos
contract Radar{
	function getDoggoSpeed(bytes32 dna, bytes32 blockhash) external returns (int);
}

//Idea: Users can queue up to indicate willingness to race in accordance to the specific charachteristics of the queue
//Once the queue closes after a set duration, participants are randomly* shuffled and split into sub-races
//Randomness is based on the blockhash of future blocks
//Winner of each subrace can claimWinnings which comes from ticketprices paid my participants of the subrace

contract DoggoRacing{
	
	event QueueCreated(uint256 queueTypeId, uint256 queueId, uint256 timeCreated);
	event QueueJoined(uint256 queueTypeId, uint256 queueId, uint256 doggoId);
	event QueueClosed(uint256 queueTypeId, uint256 queueId, uint256 closingBlockNumber);
	event QueueResolved(uint256 queueTypeId, uint256 queueId);
	event RaceCreated(uint256 raceIndex, uint256 queueId, int256 [4] doggosInRace, uint8 numDoggos,  uint256 now);
	event RaceResolved(uint256 queueTypeId, uint256 queueId, uint256 raceId, int256 [4] doggosInRace, int256 [4] doggoSpeeds, uint8 numDoggos, address winner);
	event RaceWinningsCollected(uint256 raceId, address winner, uint256 user_winnings);
	
	uint256 queueIndex = 1; //Id of next queue to be created, starts at 1 since 0 is reserved for no queue
	uint256 raceIndex = 0; //Id of next race to be created
	DoggoMain public doggoMainContract;
	Radar public radarContract;
	mapping (uint256 => Race) raceIdToRace; //mapping from raceId to struct of race
	mapping (uint256 => QueueType) queueTypeIdToQueueType; //mapping from queueTypeIdToQueueType 
	mapping (uint256 => Queue) queueIdToQueue; //mapping from queueId to struct of queue
	mapping (uint256 => uint256) doggoIdToQueueId; //mapping from doggoId to current queueId
	mapping (address => RaceAccount) addressToRaceAccount; //mapping from user address to his RaceAccount 
	uint256 ONE_ETH = 1000000000000000000;


	//Deploy using the DoggoMain contract address
	function DoggoRacing(address _doggoMainAddress, address _radarAddress) public{
		doggoMainContract = DoggoMain(_doggoMainAddress);
		radarContract = Radar(_radarAddress);

		//create default queue types
		//unhardcode this later
		QueueType memory queueType1 = QueueType(1, 1800, 0, 2, 0);
		queueTypeIdToQueueType[1] = queueType1;
		QueueType memory queueType2 = QueueType(2, 1800, ONE_ETH/4, 2, 0);
		queueTypeIdToQueueType[2] = queueType2;
		QueueType memory queueType3 = QueueType(3, 21600, 0, 3, 0);
		queueTypeIdToQueueType[3] = queueType3;
		QueueType memory queueType4 = QueueType(4, 21600, ONE_ETH/1000, 4, 0);
		queueTypeIdToQueueType[4] = queueType4;
		QueueType memory queueType5 = QueueType(5, 21600, ONE_ETH/100, 4, 0);
		queueTypeIdToQueueType[5] = queueType5;
		QueueType memory queueType6 = QueueType(6, 21600, ONE_ETH/10, 4, 0);
		queueTypeIdToQueueType[6] = queueType6;
		QueueType memory queueType7 = QueueType(7, 21600, ONE_ETH/2, 4, 0);
		queueTypeIdToQueueType[7] = queueType7;
		QueueType memory queueType8 = QueueType(8, 21600, 0, 4, 0);
		queueTypeIdToQueueType[8] = queueType8;
	}

	struct QueueType{
		uint256 queueTypeId;
		uint256 duration;		//How long queue of this type remains open 
		uint256 ticketPrice;//ticket cost to participate in the queue
		uint8 doggosPerRace;
		uint256 currentQueueId;		//id of current queue of this type
	}

	struct Queue{
		uint256 queueTypeId;
		uint256 queueId;
		uint8 status;			// 1: accepting participants, 2: queue locked awaiting new blocks, 3: participants split into races 
		uint256 [] contestants;		//doggos that have queued up
		uint256 timeQueueCreated;
		uint256 closingBlockNumber;	//blocknumber of when the queue got closed
	}
	
	struct Race{
		uint256 raceId;
		uint256 queueId;
		int256 [4] doggosInRace;
		address [4] accountsInRace;
		int256 [4] doggoSpeeds;
		uint8 numDoggos;
		address winner;
		bytes32 blockhash;
		uint256 timeStamp;
		bool isWithdrawn;
	}

	//holds leaderboard related information
	struct RaceAccount{
		address accountAddress;
		uint256 numTicketsBought;
		uint256 numRacesWon;
		uint256 ETHWon;
		
	}

	//return info about a race	
	function getRace(uint256 raceId) view public returns (uint256, uint256, int256 [4], address [4], int256 [4], uint8, address, uint256, bool){
		Race memory r = raceIdToRace[raceId];
		return(r.raceId, r.queueId, r.doggosInRace, r.accountsInRace, r.doggoSpeeds, r.numDoggos, r.winner, r.timeStamp, r.isWithdrawn);
	}

	function getQueueIdFromDoggoId(uint256 doggoId) view public returns(uint256){
		return doggoIdToQueueId[doggoId];
	}

	//return info about queue
	//does not return participants, only number of participants
	function getQueue(uint256 queueId) view public returns (uint256, uint256, uint8, uint256, uint256, uint256){
		Queue memory q  = queueIdToQueue[queueId];
		return(q.queueTypeId, q.queueId, q.status, q.timeQueueCreated, q.closingBlockNumber, q.contestants.length);
	}
	
	//return info about queue
	function getQueueType(uint256 queueTypeId) view public returns (uint256, uint256, uint256, uint8, uint256){
		QueueType memory qt  = queueTypeIdToQueueType[queueTypeId];
		return(qt.queueTypeId, qt.duration, qt.ticketPrice, qt.doggosPerRace, qt.currentQueueId);
	}
	
	//return info about queue
	function getRaceAccount(address accountAddress) view public returns (address, uint256, uint256, uint256){
		 RaceAccount memory ra  = addressToRaceAccount[accountAddress];
		return(ra.accountAddress, ra.numTicketsBought, ra.numRacesWon, ra.ETHWon);
	}


	//if no queue of the queue type exists, allow the creation of a new queue
	function createQueue(uint256 queueTypeId) public{
		QueueType storage qt  = queueTypeIdToQueueType[queueTypeId];
		Queue storage q  = queueIdToQueue[qt.currentQueueId];
		require((qt.currentQueueId == 0) || (q.status == 3));//make sure either no queue of this type exists or if it does, its races are already over
		uint256 [] memory contestants;
		Queue memory newQueue = Queue(queueTypeId, queueIndex, 1, contestants, now, 0);
		queueIdToQueue[queueIndex] = newQueue;
		qt.currentQueueId = queueIndex;
		QueueCreated(queueTypeId, queueIndex, now);	
		queueIndex++;
	}

	//doggo joins the queue and awaits to race when the queue closes
	function joinQueue(uint256 queueId, uint256 doggoId) public payable{
		require(doggoMainContract.ownerOf(doggoId) == msg.sender);
		require(doggoMainContract.getModeFromDoggoId(doggoId) == 0); //no racing allowed for doggos on Auction
		Queue storage q = queueIdToQueue[queueId];
		require(q.contestants.length <= 256); // hard cap of 256 participants in any given queue. Limits gas cost of resolveQueue transaction
		require(q.status == 1);
		QueueType memory qt = queueTypeIdToQueueType[q.queueTypeId];
		require(now < (q.timeQueueCreated + qt.duration)); //make sure queue is still open
		require(msg.value >= qt.ticketPrice);
		//sets doggo mode to racing preventing same dog from participating in multiple queues at the same time
		doggoMainContract.setModeByDoggoId(doggoId, 2);
		doggoIdToQueueId[doggoId] = q.queueId;

		RaceAccount storage ra = addressToRaceAccount[msg.sender];
		if (ra.accountAddress == msg.sender){//if already exists
			ra.numTicketsBought += 1;	
		}
		else{//create new race account
			RaceAccount memory new_ra = RaceAccount(msg.sender, 1, 0, 0);
			addressToRaceAccount[msg.sender] = new_ra;
		}

		q.contestants.push(doggoId);
		QueueJoined(qt.queueTypeId, queueId, doggoId);
	}
	
	
	//once duration of queuetype has passed since creation allow anyone to close queue
	//no more doggos are allowed to join the queue
	function closeQueue(uint256 queueId) external{
		Queue storage q = queueIdToQueue[queueId];
		QueueType memory qt  = queueTypeIdToQueueType[q.queueTypeId];
		require(q.status == 1);
		require(now >= (q.timeQueueCreated + qt.duration)); //make sure queue isclosed 
		q.status = 2;
		q.closingBlockNumber = block.number; //set current block number to be the closing block number	
		QueueClosed(qt.queueTypeId, q.queueId, q.closingBlockNumber);
	}
	

	//shuffles the contestants that singed up for the queue into subraces
	//creates each subrace
	//release rabbit can now be called to resolve each individual race
	//current blockhash is used for randomness
	function resolveQueue(uint256 queueId) public{
		Queue storage q = queueIdToQueue[queueId];
		require(q.status == 2);
		require(block.number >= (q.closingBlockNumber + 3));//have to wait at least 3 blocks between closeQueue and resolveQueue to ensure randomness on blockhash
		QueueType memory qt  = queueTypeIdToQueueType[q.queueTypeId];
		

		//shuffle contestants
		uint256 [] memory contestants = q.contestants;
                bytes32 b = block.blockhash(block.number - 1);
		uint256 j = 0;               
		uint256 i = 0;
		uint256 temp;
		uint256 rand_num;
		if(contestants.length != 0){
			for(i = (contestants.length - 1); i > 0; i--){
				temp = contestants[i];
				rand_num = uint8(b[j]) % i;
				contestants[i] = contestants[rand_num];
				contestants[rand_num] = temp;
				if(j > 31){
					j = 0;
				}
				else{
					j++;
				}
			}
				
			//Put contestants in subgroups that are used to initilize races
			int256 [4] memory doggosInRace;
			uint256 doggoId;
			for(i = 0; i < ((contestants.length)/qt.doggosPerRace); i++){
				for(j = 0; j < qt.doggosPerRace; j++){
					doggoId = contestants[i*qt.doggosPerRace + j];	
					doggosInRace[j] = int256(doggoId);	
					doggoIdToQueueId[doggoId] = 0; //doggo is no longer in queue after being placed in a race
				}

				//pad any empty slots in race with -1
				for(j = qt.doggosPerRace; j < 4; j++){
					doggosInRace[j] = -1;	
				}	
				createRace(doggosInRace, queueId, qt.doggosPerRace, b);
			}
				
				
			//place remaining dogs that don't fit into a full race of the size qt.doggosPerRace
			//if a single dog remains he is placed in a 1 man race where he can get a refund
			uint256 numRemainderDoggos =  contestants.length % qt.doggosPerRace;
			if(numRemainderDoggos > 0){
				for(i = 0; i < numRemainderDoggos; i++){
					doggoId = contestants[contestants.length -1 -i];
					doggosInRace[i] = int256(doggoId);
					doggoIdToQueueId[doggoId] = 0; //doggo is no longer in queue after being placed in a race
				
				}
				for(j = numRemainderDoggos; j < 4; j++){
					doggosInRace[j] = -1;	
				}	
				createRace(doggosInRace, queueId, uint8(numRemainderDoggos), b);
			}
		}
		
		q.status = 3;// set status to resolved, allows for new queue creation of the same type
		QueueResolved(qt.queueTypeId, q.queueId);
		
	}
	

	function createRace(int256 [4] doggosInRace, uint256 queueId, uint8 numDoggos, bytes32 blockhash) private{
		int [4] memory speeds;
		address winner;
		address [4] memory accountsInRace;
		for(uint i = 0; i < numDoggos; i++){
			accountsInRace[i] = doggoMainContract.ownerOf(uint256(doggosInRace[i]));
		}
		Race memory newRace = Race(raceIndex, queueId, doggosInRace, accountsInRace, speeds, numDoggos, winner, blockhash, now, false);
		raceIdToRace[raceIndex] = newRace;
		raceIndex++;
		RaceCreated(raceIndex, queueId, doggosInRace, numDoggos, now);
	}
	

	//calculate doggo Speeds and finalize results of race
	function releaseRabbit(uint256 raceId) public{
		Race storage r = raceIdToRace[raceId];
		require(r.queueId != 0);//make sure race exists
		Queue memory q = queueIdToQueue[r.queueId];
		QueueType memory qt  = queueTypeIdToQueueType[q.queueTypeId];
		
		int256 topSpeed = -2**255+1;
		uint256 fastestDoggoId;
		for(uint8 i = 0; i < qt.doggosPerRace; i++){
			if(r.doggosInRace[i] != -1){//doggo 0 cannot race atm
				bytes32 dna = doggoMainContract.getDNAFromDoggoId(uint256(r.doggosInRace[i]));	
				r.doggoSpeeds[i] = radarContract.getDoggoSpeed(dna, r.blockhash);
				if(r.doggoSpeeds[i] > topSpeed){
					topSpeed = r.doggoSpeeds[i];
					fastestDoggoId = uint256(r.doggosInRace[i]);
				}
				
				doggoMainContract.setModeByDoggoId(uint256(r.doggosInRace[i]), 0);//reset doggo modes releasing dogs
			}
		}
		r.winner = doggoMainContract.ownerOf(fastestDoggoId);
		RaceResolved(qt.queueTypeId, q.queueId, r.raceId, r.doggosInRace, r.doggoSpeeds, r.numDoggos, r.winner);
	}
	
	//winner of the race can call this to withdraw winnings of the race
	function claimWinnings(uint256 raceId) public{
		Race storage r = raceIdToRace[raceId];
		require(r.winner == msg.sender); //prevent stealing of race winnings
		require(!r.isWithdrawn); //prevent double withdrawl
		require(r.queueId != 0);//make sure race exists
		Queue memory q = queueIdToQueue[r.queueId];
		QueueType memory qt = queueTypeIdToQueueType[q.queueTypeId]; 
		uint256 total_winnings = r.numDoggos * qt.ticketPrice;
		
		//update race account stats
		RaceAccount storage ra = addressToRaceAccount[msg.sender];
		ra.ETHWon += total_winnings;
		ra.numRacesWon += 1;

		r.isWithdrawn = true;
		doggoMainContract.getCFOAddress().transfer(2*total_winnings/100); //2% Fee
		msg.sender.transfer(98*total_winnings/100);//98% goes to winner of race
		RaceWinningsCollected(r.raceId, r.winner, 98*total_winnings/100);
	}
}
