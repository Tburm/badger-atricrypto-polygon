interface ICurvePool {
    function get_virtual_price() external view returns (uint256);

    function add_liquidity(uint256[5] calldata amounts, uint256 min_mint_amount)
        external;

    /*
    @notice Deposit coins into the pool
    @param _amounts List of amounts of coins to deposit
    @param _min_mint_amount Minimum amount of LP tokens to mint from the deposit
    @param _use_underlying If True, deposit underlying assets instead of aTokens
    @return Amount of LP tokens received by depositing
    */
    function add_liquidity(uint256[3] calldata amounts, uint256 min_mint_amount, bool use_underlying)
        external;

    function remove_liquidity_imbalance(
        uint256[2] calldata amounts,
        uint256 max_burn_amount
    ) external;

    function remove_liquidity(uint256 _amount, uint256[2] calldata amounts)
        external;

    function exchange(
        int128 from,
        int128 to,
        uint256 _from_amount,
        uint256 _min_to_amount
    ) external;

    function balances(uint256) external view returns (uint256);
    
}