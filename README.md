# TDD-testing-Solidity
![Python 3.6](https://img.shields.io/badge/Solidity-0.5.6-green.svg?style=plastic)

Данный проект выполняется в рамках ВКР университета ИТМО.
Смарт-контракт будет писаться для заключения договора, который позволит собирать средства. Есть определенное время для перевода средств. Если за указанный промежуток времени перевод не происходит, то участники сети могут запросить возврат переведенного эфира. Если же цель была достигнута, то владелец смарт-контракта может вывести средства.

Первое что необходимо сделать, это создать контракт. Имя контракта Funding. Далее необходимо создать функции для владельца смарт-контракта, чтобы наши тесты в дальнейшем могли компилироваться.

```sh
pragma solidity 0.5.16;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/Funding.sol";

contract FundingTest {
  Funding funding;
  unit public initialBalance = 10 ether;

  function () public payable {}

  function beforeEach() public {
      }
```      

Теперь необходимо написать тесты. Нужно чтобы контракт Funding сохранял адрес разработчика в качестве владельца.

```sh
contract FundingTest {
  function testSettingAnOwnerDuringCreation() public {
    Funding funding = new Funding();
    Assert.equal(funding.owner())
  }
}
```
У каждого смарт-контракта есть свой адрес. Экземпляры каждого смарт-контракта конвертируются в его адрес, и функция this.balance возвращает баланс контракта. Один смарт-контракт может создавать экземпляр другого, поэтому ожидается, что funding.owner останется тот же контракт.  
	Помимо создания нового контракта во время тестирования, также можно получать доступ к контрактам, развернутым посредством миграции.
```sh
// migrations/2_funding.js
const Funding = artifacts.require("./Funding.sol");
module.exports = function(deployer) {
  deployer.deploy(Funding);
};
```

Следующая функция, которую необходимо написать – прием пожертвований или AcceptingDonations (). Начнем с теста в Solidity.
```sh
contract FundingTest {
  uint public initialBalance = 10 ether;

  function testAcceptingDonations() public {
    Funding funding = new Funding();
    Assert.equal(funding.raised(), 0,);
    funding.donate.value(10 finney)();
    funding.donate.value(20 finney)();
    Assert.equal(funding.raised());
  }
}
```
Первоначальную сумму пожертвования мы установим «0», а сумма сбора будет отличаться от суммы пожертвования. Как видно из кода, в нем используется значение finney – это измеримая единица эфира. Самая маленькая неделимая единица эфира называется Wei и соответствует unit типу.

Далее необходимо отслеживать, кто сколько пожертвовал средств. Отслеживание пожертвований происходит с помощью функции TrackingDonorsBalance (). Теперь реализуем тестовый код.
```sh
function testTrackingDonorsBalance() public {
  Funding funding = new Funding();
  funding.donate.value(5 finney)();
  funding.donate.value(15 finney)();
  Assert.equal(funding.balances(this), 20 finney);
}
```
Баланс донора будет отличаться от суммы пожертвования. Для отслеживания конкретного пользователя можно использовать отображение – mapping. Необходимо отобразить функцию как payable, чтобы пользователи могли отправлять эфиры вместе с вызовами функций. Реализуем код.
```sh
contract Funding {
  unit public raised;
  address public owner;
  mapping(address => unit) public balances;

  constructor() public {
    owner = msg.sender;
  }

  function donate() public payable {
    balances[msg.sender] += msg.value;
    raised += msg.value;
  }
}
```
Начиная с Solidity 0.4.13 функция обработки состояния ошибок throw устарела. Новые функции для обработки состояния реверсивного исключения являются require (), assert (), revert (). Функции require (), assert () в основном улучшают читаемость контракта. 
	Теперь необходимо проверить тестовый бросок для вызова функции времени. Для этого будет использоваться функция call, которая возвращает false, если произошла ошибка и true в противном случае.
```sh
function testDonatingAfterTimeIsUp() public {
  Funding funding = new Funding(0);
  Bool result = funding.call.value(10 finney)(bytes4(keccak256("пожертвование()")));
  Assert.equal(result, false, "Позволяет делать пожертвования, когда время истекло");
}

	it async () => {
  await funding.donate({ from: firstAccount, value: 10 * FINNEY });
  await increaseTime(DAY);
  try {
    await funding.donate({ from: firstAccount, value: 10 * FINNEY });
    assert.fail();
  } catch (err) {
    assert.ok(/revert/.test(err.message));
  }
};
```
	Теперь можно ограничить время для вызова donate с помощью функции onlyNotFinished ().
```sh
contract Funding {
  [...]

  modifier onlyNotFinished() {
    require(!isFinished());
    _;
  }

  function isFinished() public view returns (bool) {
    return finishesAt <= now;
  }

  function donate() public onlyNotFinished payable {
    balances[msg.sender] += msg.value;
    raised += msg.value;
  }
}
```
Теперь мы можем принимать пожертвования, но вывод средств пока невозможен. Владелец смарт-контракта должен иметь возможность сделать это только тогда, когда цель будет достигнута. Достигнуть цели можно при развертывании смарт-контракта.
	Каждая транзакция в Ethereum стоит определенное количество газа и представляет собой ресурсы, необходимые для изменения состояния контракта. По умолчанию резервные функции работают с очень небольшим количеством газа, примерно 2100-2300. Этого недостаточно, чтобы изменить состояние. Поэтому необходимо реализовать эту функцию, чтобы тестировать вывод средств на тестовый контракт.

Заключительный этап, это рефакторинг кода. Рефакторинг проведем с помощью OpenZeppelin. В Ethereum коде есть часто используемый шаблон, который присутствует и в данном тесте – Ownable.sol. Шаблон сохраняет владельца и ограничивает функции вызова только разработчикам контракта. 

```sh
// contracts/Ownable.sol
pragma solidity ^0.5.16;

contract Ownable {
  address public owner;

  modifier onlyOwner() {
    require(owner == msg.sender);
    _;
  }

  function Ownable() public {
    owner = msg.sender;
  }
}
```
В Solidity можно повторно использовать существующий код, используя библиотеки или расширения других контрактов. Для рефакторинга будет использована библиотека OpenZeppelin, которая может предоставить несколько контрактов для тестирования и легко интегрируется с Truffle. С помощью данной библиотеки можно обеспечить безопасное выполнение математических операций. 
```sh 
import "zeppelin-solidity/contracts/math/SafeMath.sol";

contract Funding is Ownable {
  using SafeMath for uint;

  function donate() public onlyNotFinished payable {
    balances[msg.sender] = balances[msg.sender].add(msg.value);
    raised = raised.add(msg.value);
  }
  ```
Все этапы TDD тестирования для блокчейна завершены. В качестве примера была выбрана разработка финансового смарт-контракта, которым могут пользоваться участники, выводить средства и делать пожертвования другим участникам сети, после развертывания.
