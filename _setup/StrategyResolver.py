from helpers.StrategyCoreResolver import StrategyCoreResolver
from rich.console import Console

console = Console()


class StrategyResolver(StrategyCoreResolver):
    def get_strategy_destinations(self):
        """
        Track balances for all strategy implementations
        (Strategy Must Implement)
        """
        strategy = self.manager.strategy
        return {
            "gauge": strategy.CURVE_TRICRYPTO_GAUGE()
        }

    def hook_after_confirm_withdraw(self, before, after, params):
        """
        Specifies extra check for ordinary operation on withdrawal
        Use this to verify that balances in the get_strategy_destinations are properly set
        """
        assert after.balances("want", "gauge") < before.balances("want", "gauge")

    def hook_after_confirm_deposit(self, before, after, params):
        """
        Specifies extra check for ordinary operation on deposit
        Use this to verify that balances in the get_strategy_destinations are properly set
        """
        assert True  ## Done in earn

    def hook_after_earn(self, before, after, params):
        """
        Specifies extra check for ordinary operation on earn
        Use this to verify that balances in the get_strategy_destinations are properly set
        """
        assert after.balances("want", "gauge") > before.balances("want", "gauge")


    def confirm_tend(self, before, after, tx):
        """
            Tend Should;
            - Increase the number of staked tended tokens in the strategy-specific mechanism
            - Reduce the number of tended tokens in the Strategy to zero

            (Strategy Must Implement)
            """
        assert after.get("strategy.isTendable") == True
        if before.get("strategy.balanceOfWant") > 0:
            assert after.get("strategy.balanceOfWant") == 0
            assert after.get("strategy.balanceOfPool") > before.get(
                "strategy.balanceOfPool")

    # def confirm_harvest(self, before, after, tx):
    # NOTE: Add this in mix 1.5 but comment for tests in main repo
    #     """
    #     Verfies that the Harvest produced yield and fees
    #     """
    #     console.print("=== Compare Harvest ===")
    #     self.manager.printCompare(before, after)
    #     self.confirm_harvest_state(before, after, tx)

    #     valueGained = after.get("sett.getPricePerFullShare") > before.get(
    #         "sett.getPricePerFullShare"
    #     )

    #     assert True
