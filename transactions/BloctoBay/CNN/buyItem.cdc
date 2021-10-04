import FungibleToken from 0xFUNGIBLE_TOKEN_ADDRESS
import NonFungibleToken from 0xNON_FUNGIBLE_TOKEN_ADDRESS
import NFTStorefront from 0xNFTStorefront_ADDRESS
import Marketplace from 0xBLOCTO_BAY_MARKETPLACE_ADDRESS
import FlowToken from 0xFLOW_TOKEN_ADDRESS
import CNN_NFT from 0xCNN_NFT_ADDRESS

transaction(listingResourceID: UInt64, storefrontAddress: Address, buyPrice: UFix64) {
    let paymentVault: @FungibleToken.Vault
    let cnnNFTCollection: &CNN_NFT.Collection{NonFungibleToken.Receiver}
    let storefront: &NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}
    let listing: &NFTStorefront.Listing{NFTStorefront.ListingPublic}

    prepare(signer: AuthAccount) {
        // Create a collection to store the purchase if none present
        if signer.borrow<&CNN_NFT.Collection>(from: CNN_NFT.CollectionStoragePath) == nil {
            signer.save(<- CNN_NFT.createEmptyCollection(), to: CNN_NFT.CollectionStoragePath)
            signer.link<&CNN_NFT.Collection{NonFungibleToken.CollectionPublic, CNN_NFT.CNN_NFTCollectionPublic}>(
			    CNN_NFT.CollectionPublicPath,
			    target: CNN_NFT.CollectionStoragePath
		    )
        }

        self.storefront = getAccount(storefrontAddress)
            .getCapability<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(NFTStorefront.StorefrontPublicPath)
            .borrow()
            ?? panic("Could not borrow Storefront from provided address")

        self.listing = self.storefront.borrowListing(listingResourceID: listingResourceID)
            ?? panic("No Offer with that ID in Storefront")
        let price = self.listing.getDetails().salePrice

        assert(buyPrice == price, message: "buyPrice is NOT same with salePrice")

        let flowTokenVault = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Cannot borrow FlowToken vault from signer storage")
        self.paymentVault <- flowTokenVault.withdraw(amount: price)

        self.cnnNFTCollection = signer.borrow<&CNN_NFT.Collection{NonFungibleToken.Receiver}>(from: CNN_NFT.CollectionStoragePath)
            ?? panic("Cannot borrow NFT collection receiver from account")
    }

    execute {
        let item <- self.listing.purchase(payment: <-self.paymentVault)

        self.cnnNFTCollection.deposit(token: <-item)

        // Be kind and recycle
        self.storefront.cleanup(listingResourceID: listingResourceID)
        Marketplace.removeListing(id: listingResourceID)
    }

}