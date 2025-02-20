// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
// 众筹合约demo
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// 1. 让合约可以收款，所以需要创建一个收款函数
// 2. 记录投资人并且查看
// 3. 在锁定期内（一定时间）达到目标值，生产商可以提款
// 4. 在锁定期内没有达到目标值，投资人可以退款

contract FundMe {
    // 记录投资人，key是投资人地址，value是金额
    mapping(address => uint256) public funderToAmount;

    // 1 * 10的18次方，即1个以太
    // uint256 MINIMUM_VALUE = 1 * 10 ** 18;
    // 最少转换100美元
    uint256 constant MINIMUM_VALUE = 100 * 10 ** 18; // USD

    AggregatorV3Interface internal dataFeed;

    // constant 常量
    uint256 constant TARGET = 1000 * 10 ** 18;

    // 合约拥有者，在构造函数中初始化
    address public owner;

    /*
     构造函数
     使用了第三方函数，必须把合约部署到测试网
     不能本地测试
     */
    constructor() {
        // 合约地址从预言机找https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1&search=
        dataFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        // 第一次调用（当时部署这个合约的人），就是这个合约的所有者
        owner = msg.sender;
    }

    // 转移合约所有权
    function transferOwnership(address newOwner) public {
        // 保证调用者是这个合约的所有人
        require(msg.sender == owner, "this function can only be called by owner");
        owner = newOwner;
    }

    // 1. 让合约可以收款，所以需要创建一个收款函数
    function fund() external payable {
        // 断言第一个参数一定是true。如果是false，交易会回退，并提示第二个参数的内容
        require(convertEthToUsd(msg.value) >= MINIMUM_VALUE, "Send More Eth");
        // 2. 记录投资人并且查看
        funderToAmount[msg.sender] += msg.value;
    }

    // 获取预言机
    function getChainlinkDataFeedLatestAnswer() public view returns (int) {
        // prettier-ignore
        (
            /* uint80 roundID */,
            int answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();
        return answer;
    }

    // 转化eth的价格为usd，参数为eth数量 
    function convertEthToUsd(uint256 ethAmount) internal view returns(uint256) {
        // 数据类型强转
        uint256 ethPrice = uint(getChainlinkDataFeedLatestAnswer());
        // 币价后面有8位是精度
        return ethAmount * ethPrice / (10 ** 8);
        // ETH / USD precision = 10 ** 8
        // X / ETH presion = 10 ** 18
    }

    function getFund() external {
        // 3. 在锁定期内（一定时间）达到目标值，生产商可以提款
        // address(this)：获取当前合约地址，this是当前合约
        // 当前合约地址.balance：获取这个地址下总数量，单位wei
        require(convertEthToUsd(address(this).balance) >= TARGET, "Target is not reched");
        // 三种转账方式。以太坊官方建议使用call
        // transfer：交易，如果失败了则revert，钱不会减少，收款人不会增加，只会损失一些gasfee
        // 必须把地址转换成payable才能交易
        // payable(msg.sender).transfer(address(this).balance);
        // send：交易，return bool，表示交易是否成功
        // bool success = payable(msg.sender).send(address(this).balance);
        // call，官方建议的转账方式
        // 交易，可以调用其他的payable函数，且会返回两个变量，一个是call返回值，bool类型。一个是函数的返回值。
        // 语法：(bool, result) = addr.call{value: tokenCount}(fun)
        // 没有调用函数，第二个返回值不需要写
        bool success;
        (success, ) = payable(msg.sender).call{value: address(this).balance}("");
    }

}