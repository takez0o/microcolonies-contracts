//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./Interfaces/ITournament.sol";

contract MicroColonies is Initializable, OwnableUpgradeable {
    Schedule public schedule;
    Tariff public tariff;
    ITournament public tournament;
    uint256 private nonce;
    address[] public participants;

    struct Schedule {
        uint256 epoch;
        uint8 workerFarm;
        uint8 workerBuild;
        uint8 conversion;
        uint8 soldierRaid;
        uint256 zombification;
        uint8 zombieHarvest;
        uint8 zombieGuard;
        uint8 incubation;
        uint8 queenPeriod;
        uint8 lollipopDuration;
        uint256 mating;
    }
    struct Tariff {
        uint256 larvaPortion;
        uint256 queenPortion;
        uint256 queenUpgrade;
        uint256 conversion;
        uint256 zombieHarvest;
        uint256 farmReward;
        uint256 buildReward;
        uint256 soldierHeal;
    }
    struct Q {
        uint256 level;
        uint256 eggs;
        uint256 timestamp;
        // Mission mission; // IMPLEMENT!!
    }
    struct L {
        Mission mission; // missionType (0-unfed, 1-fed)
    }
    struct W {
        uint8 hp;
        Mission mission; // missionType (0-farm, 1-build, 2-conversion)
    }
    struct S {
        uint256 hp; // 2 full 1 infected 0 dead
        Mission mission; // missionType (0-scout)
        uint256 damageTimestamp;
    }
    struct Z {
        Mission mission; // missionType (0-harvest, 1-defend)
    }
    struct M {
        Mission mission;
    }
    struct P {
        Mission mission;
    }
    struct Lolli {
        bool used;
        uint256 timestamp;
    }

    struct Mission {
        uint256 missionId;
        uint256 missionType;
        uint256 missionTimestamp;
        bool missionFinalized;
    }

    struct Inhibition {
        uint256 start;
        uint256 end;
        bool deploy;
    }

    enum MissionState {
        NULL,
        INITIALIZED,
        COMPLETED
    }

    // battle (50) 50 soldier -> WRITE +50

    /// @dev user => QLWSMPZ => ids
    mapping(address => mapping(uint256 => uint256[])) public userIds;
    mapping(address => mapping(uint256 => uint256[])) public userMissions; // convert to Mission[]
    mapping(address => mapping(uint256 => mapping(uint256 => uint256[])))
        public missionIds;
    mapping(address => mapping(uint256 => mapping(uint256 => MissionState)))
        public missionStates;
    mapping(address => Lolli) public lollipops;
    mapping(address => uint256) public funghiBalance;
    mapping(address => uint256) public feromonBalance;
    mapping(address => uint256) public capacity;
    mapping(address => uint256) public nested;
    mapping(uint256 => uint256[]) public access;
    mapping(uint256 => address) public modules;
    mapping(uint256 => Inhibition) public inhibitions;

    /// @dev QLWSMPZ(0123456) => counter;
    mapping(uint256 => uint256) counters;
    mapping(uint256 => Q) public q;
    mapping(uint256 => L) public l;
    mapping(uint256 => W) public w;
    mapping(uint256 => S) public s;
    mapping(uint256 => Z) public z;
    mapping(uint256 => M) public m;
    mapping(uint256 => P) public p;

    // modifier
    modifier xp(uint256 _amount) {
        feromonBalance[msg.sender] += _amount;
        _;
    }

    modifier checkAccess(uint256 _type, uint256 _targetType) {
        // _checkAccess(_type, _targetType);
        _;
    }

    // function _checkAccess(uint256 _type, uint256 _targetType)
    //     public
    //     view
    //     virtual
    // {
    //     bool passed;
    //     for (uint256 i; i < access[_type].length; i++) {
    //         if (access[_type][i] == _targetType) {
    //             passed = true;
    //         }
    //     }
    //     if (_type == _targetType) {
    //         passed = true;
    //     }
    //     require(passed);
    // }

    // initializer
    function initialize(uint256 _epoch, address[] calldata _participants)
        external
        initializer
    {
        tournament = ITournament(msg.sender);
        participants = _participants;
        schedule.epoch = _epoch;
        schedule.workerFarm = 1;
        schedule.workerBuild = 5;
        schedule.conversion = 1;
        schedule.soldierRaid = 3;
        schedule.zombification = 5;
        schedule.zombieHarvest = 5;
        schedule.zombieGuard = 1;
        schedule.incubation = 1;
        schedule.queenPeriod = 1;
        schedule.lollipopDuration = 1;
        schedule.mating = 4;
        tariff.larvaPortion = 400;
        tariff.queenPortion = 240;
        tariff.queenUpgrade = 1000;
        tariff.conversion = 10; // 100 in production!
        tariff.zombieHarvest = 400;
        tariff.farmReward = 80;
        tariff.buildReward = 5;
        tariff.soldierHeal = 80;
        nonce = 42;
    }

    // admin fxns
    function setAccess(
        uint256 _moduleId,
        address _moduleAddr,
        uint256[] calldata _targetAddrs
    ) public onlyOwner {
        access[_moduleId] = _targetAddrs;
        modules[_moduleId] = _moduleAddr;
    }

    // view fxn
    function getParticipants()
        public
        view
        returns (address[] memory participants_)
    {
        participants_ = participants;
    }

    function getUserSpeed(address _user) public view returns (uint256 speed) {
        speed = lollipops[_user].timestamp + schedule.lollipopDuration >
            block.timestamp
            ? 2
            : 1;
    }

    function getUserIds(
        address _user,
        uint256 _type,
        bool _available
    ) public view returns (uint256[] memory ids) {
        ids = new uint256[](getLength(_user, _type, true));
        uint256 total = getLength(_user, _type, false);
        uint256 counter;
        if (_available) {
            for (uint256 i; i < total; i++) {
                if (
                    (_type == 1 &&
                        (l[userIds[_user][_type][i]].mission.missionFinalized ||
                            l[userIds[_user][_type][i]]
                                .mission
                                .missionTimestamp ==
                            0)) ||
                    (_type == 2 &&
                        (w[userIds[_user][_type][i]].mission.missionFinalized ||
                            w[userIds[_user][_type][i]]
                                .mission
                                .missionTimestamp ==
                            0)) ||
                    (_type == 3 &&
                        (s[userIds[_user][_type][i]].mission.missionFinalized ||
                            s[userIds[_user][_type][i]]
                                .mission
                                .missionTimestamp ==
                            0)) ||
                    (_type == 4 &&
                        (m[userIds[_user][_type][i]].mission.missionFinalized ||
                            m[userIds[_user][_type][i]]
                                .mission
                                .missionTimestamp ==
                            0)) ||
                    (_type == 6 &&
                        (z[userIds[_user][_type][i]].mission.missionFinalized ||
                            z[userIds[_user][_type][i]]
                                .mission
                                .missionTimestamp ==
                            0)) ||
                    (_type == 5 &&
                        (p[userIds[_user][_type][i]].mission.missionFinalized ||
                            p[userIds[_user][_type][i]]
                                .mission
                                .missionTimestamp ==
                            0))
                ) {
                    ids[counter] = userIds[_user][_type][i];
                    counter++;
                }
            }
        } else {
            ids = userIds[_user][_type];
        }
    }

    function getMissionState(
        address _user,
        uint256 _type,
        uint256 _id
    ) public view returns (MissionState state) {
        state = missionStates[_user][_type][_id];
    }

    function getLength(
        address _user,
        uint256 _type,
        bool _available
    ) public view returns (uint256 length) {
        if (_available) {
            for (uint256 i; i < userIds[_user][_type].length; i++) {
                if (
                    (_type == 0) ||
                    (_type == 1 &&
                        (l[userIds[_user][_type][i]].mission.missionFinalized ||
                            l[userIds[_user][_type][i]]
                                .mission
                                .missionTimestamp ==
                            0)) ||
                    (_type == 2 &&
                        (w[userIds[_user][_type][i]].mission.missionFinalized ||
                            w[userIds[_user][_type][i]]
                                .mission
                                .missionTimestamp ==
                            0)) ||
                    (_type == 3 &&
                        (s[userIds[_user][_type][i]].mission.missionFinalized ||
                            s[userIds[_user][_type][i]]
                                .mission
                                .missionTimestamp ==
                            0)) ||
                    (_type == 4 &&
                        (m[userIds[_user][_type][i]].mission.missionFinalized ||
                            m[userIds[_user][_type][i]]
                                .mission
                                .missionTimestamp ==
                            0)) ||
                    (_type == 6 &&
                        (z[userIds[_user][_type][i]].mission.missionFinalized ||
                            z[userIds[_user][_type][i]]
                                .mission
                                .missionTimestamp ==
                            0)) ||
                    (_type == 5 &&
                        (p[userIds[_user][_type][i]].mission.missionFinalized ||
                            p[userIds[_user][_type][i]]
                                .mission
                                .missionTimestamp ==
                            0))
                ) {
                    length++;
                }
            }
        } else {
            length = userIds[_user][_type].length;
        }
    }

    function getUserMissions(address _user, uint256 _type)
        public
        view
        returns (uint256[] memory ids)
    {
        ids = userMissions[_user][_type];
    }

    function getMissionIds(
        address _user,
        uint256 _type,
        uint256 _id
    ) public view returns (uint256[] memory) {
        return missionIds[_user][_type][_id];
    }

    function isBoosted(
        address _user,
        uint256 _type,
        uint256 _id
    ) public view returns (bool) {
        if (
            _type == 1 &&
            l[_id].mission.missionTimestamp > lollipops[_user].timestamp &&
            l[_id].mission.missionTimestamp <=
            (lollipops[_user].timestamp + schedule.lollipopDuration)
        ) {
            return true;
        }
        return false;
    }

    // mutate fxn
    function setNonce(uint256 _type, uint256 _targetType)
        public
        checkAccess(_type, _targetType)
        returns (uint256 nextNonce)
    {
        nonce = uint256(keccak256(abi.encodePacked(msg.sender, nonce)));
        nextNonce = nonce;
    }

    function openPack(address _user, uint256 _pack) public {
        require(msg.sender == address(tournament), "Only tournament can call.");
        increaseCapacity(0, 0, _user, 20);
        if (_pack == 0) {
            print(_user, 1, 1, 20);
        } else if (_pack == 1) {
            print(_user, 0, 1, 15);
            print(_user, 0, 5, 1);
        } else if (_pack == 2) {
            print(_user, 0, 1, 10);
            print(_user, 0, 0, 1);
        }
        funghiBalance[_user] = 100000; // remove at production!
        feromonBalance[_user] = 100000; // remove at production!
    }

    function useLollipop() public {
        require(!lollipops[msg.sender].used);
        lollipops[msg.sender].used = true;
        lollipops[msg.sender].timestamp = block.timestamp;
    }

    // princess + male
    function matingBoost(
        address _user,
        uint256 _type,
        uint256 _targetType
    ) public checkAccess(_type, _targetType) {
        lollipops[_user].timestamp = block.timestamp;
    }

    function inhibit(
        uint256 _type,
        uint256 _targetType,
        uint256 _epochs,
        bool _deploy
    ) public checkAccess(_type, _targetType) {
        inhibitions[_targetType].start = block.timestamp;
        inhibitions[_targetType].end = _epochs * tournament.epochDuration();
        inhibitions[_targetType].deploy = _deploy;
    }

    function findIndex(
        address _user,
        uint256 _type,
        uint256 _id
    ) private view returns (uint256 index) {
        for (uint256 i; i < userIds[_user][_type].length; i++) {
            if (userIds[_user][_type][i] == _id) {
                index = i;
            }
        }
    }

    function kill(
        address _user,
        uint256 _type,
        uint256 _targetType,
        uint256 _id
    ) public checkAccess(_type, _targetType) {
        uint256 index = findIndex(_user, _targetType, _id);
        if (userIds[_user][_targetType].length > 0) {
            userIds[_user][_targetType][index] = userIds[_user][_targetType][
                userIds[_user][_targetType].length - 1
            ];
        }
        userIds[_user][_targetType].pop();
        if (_targetType != 1) {
            nested[_user]--;
        }
    }

    function print(
        address _user,
        uint256 _type,
        uint256 _targetType,
        uint256 _amount
    ) public checkAccess(_type, _targetType) {
        if (_targetType != 1) {
            require(
                _amount <= (capacity[_user] - nested[_user]),
                "You don't have enough nest capacity."
            );
        }
        for (uint256 i; i < _amount; i++) {
            if (_targetType == 0) {
                q[counters[0]] = Q(1, 0, block.timestamp);
            } else if (_targetType == 1) {
                l[counters[1]] = L(Mission(0, 0, 0, false));
            } else if (_targetType == 5) {
                p[counters[5]] = P(Mission(0, 0, 0, false));
            } else if (_targetType == 4) {
                m[counters[4]] = M(Mission(0, 0, 0, false));
            } else if (_targetType == 3) {
                s[counters[3]] = S(2, Mission(0, 0, 0, false), 0);
            } else if (_targetType == 2) {
                w[counters[2]] = W(5, Mission(0, 0, 0, false));
            } else if (_targetType == 6) {
                z[counters[6]] = Z(Mission(0, 0, 0, false));
            }
            userIds[_user][_targetType].push(counters[_targetType]);
            counters[_targetType]++;
            if (_targetType != 1) {
                nested[_user]++;
            }
        }
    }

    function createMission(
        address _user,
        uint256 _type,
        uint256 _targetType
    ) public checkAccess(_type, _targetType) returns (uint256 highest) {
        if (userMissions[_user][_targetType].length > 0) {
            highest =
                userMissions[_user][_targetType][
                    userMissions[_user][_targetType].length - 1
                ] +
                1;
        } else {
            highest = 1;
        }
        missionStates[_user][_targetType][highest] = MissionState(1);
        userMissions[_user][_targetType].push(highest);
    }

    function addToMission(
        address _user,
        uint256 _type,
        uint256 _targetType,
        uint256 _missionType,
        uint256 _id,
        uint256 _missionId
    ) public checkAccess(_type, _targetType) {
        Mission memory mission = Mission(
            _missionId,
            _missionType,
            block.timestamp,
            false
        );
        if (_targetType == 1) {
            l[_id].mission = mission;
        } else if (_targetType == 2) {
            w[_id].mission = mission;
        } else if (_targetType == 3) {
            s[_id].mission = mission;
        } else if (_targetType == 4) {
            m[_id].mission = mission;
        } else if (_targetType == 5) {
            p[_id].mission = mission;
        } else if (_targetType == 6) {
            z[_id].mission = mission;
        }
        missionIds[_user][_targetType][_missionId].push(_id);
    }

    function finalizeMission(
        address _user,
        uint256 _type,
        uint256 _targetType,
        uint256 _id
    ) public checkAccess(_type, _targetType) {
        uint256[] memory ids = getMissionIds(_user, _targetType, _id);
        for (uint256 i; i < ids.length; i++) {
            if (_targetType == 1) {
                l[ids[i]].mission.missionFinalized = true;
            } else if (_targetType == 2) {
                w[ids[i]].mission.missionFinalized = true;
            } else if (_targetType == 3) {
                s[ids[i]].mission.missionFinalized = true;
            } else if (_targetType == 4) {
                m[ids[i]].mission.missionFinalized = true;
            } else if (_targetType == 5) {
                p[ids[i]].mission.missionFinalized = true;
            } else if (_targetType == 6) {
                z[ids[i]].mission.missionFinalized = true;
            }
        }
        missionStates[_user][_targetType][_id] = MissionState(2);
    }

    function earnXp(
        uint256 _type,
        uint256 _targetType,
        address _user,
        uint256 _amount
    ) public checkAccess(_type, _targetType) {
        feromonBalance[_user] += _amount;
    }

    // worker farm + zombie harvest
    function earnFunghi(
        uint256 _type,
        uint256 _targetType,
        address _user,
        uint256 _amount
    ) public checkAccess(_type, _targetType) {
        funghiBalance[_user] += _amount;
    }

    function spendFunghi(
        uint256 _type,
        uint256 _targetType,
        address _user,
        uint256 _amount
    ) public checkAccess(_type, _targetType) {
        funghiBalance[_user] -= _amount;
    }

    function spendFeromon(
        uint256 _type,
        uint256 _targetType,
        address _user,
        uint256 _amount
    ) public checkAccess(_type, _targetType) {
        feromonBalance[_user] -= _amount;
    }

    // queen-only
    function resetQueen(
        uint256 _type,
        uint256 _targetType,
        uint256 _id
    ) public checkAccess(_type, _targetType) {
        q[_id].timestamp = block.timestamp;
        q[_id].eggs = 0;
    }

    function increaseCapacity(
        uint256 _type,
        uint256 _targetType,
        address _user,
        uint256 _amount
    ) public checkAccess(_type, _targetType) {
        capacity[_user] += _amount;
    }

    function decreaseCapacity(
        uint256 _type,
        uint256 _targetType,
        address _user,
        uint256 _amount
    ) public checkAccess(_type, _targetType) {
        capacity[_user] -= _amount;
    }

    // worker + soldier
    function decreaseHP(
        uint256 _type,
        uint256 _targetType,
        uint256 _id
    ) public checkAccess(_type, _targetType) {
        if (_targetType == 2) {
            require(w[_id].hp > 0, "Worker is dead already.");
            w[_id].hp--;
        } else if (_targetType == 3) {
            require(s[_id].hp > 0, "Soldier is dead already.");
            s[_id].hp--;
        }
    }

    // queen-only
    function addEggs(
        uint256 _type,
        uint256 _targetType,
        uint256 _id,
        uint256 _amount
    ) public checkAccess(_type, _targetType) {
        q[_id].eggs += _amount;
    }

    function queenLevelup(
        uint256 _id,
        uint256 _type,
        uint256 _targetType
    ) public checkAccess(_type, _targetType) {
        q[_id].level++;
    }

    // soldier-only
    function healSoldier(
        uint256 _type,
        uint256 _targetType,
        uint256 _id
    ) public checkAccess(_type, _targetType) {
        s[_id].hp == 2;
        s[_id].damageTimestamp = 0;
    }
}
