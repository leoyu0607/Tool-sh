const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
        const confirmButton = document.querySelector(".response-content-btns .button");
        if (confirmButton && confirmButton.textContent.includes("確定")) {
            console.log("準備自動點擊");
            confirmButton.click();
            console.log("完成自動點擊");
        }
    });
});

const targetNode = document.body;

const config = {
    childList: true, 
    subtree: true    
};

observer.observe(targetNode, config);
console.log("監控彈窗");